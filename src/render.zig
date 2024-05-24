const std = @import("std");
const mach = @import("mach");
const mesh = @import("mesh.zig");

pub const RenderContext = struct {
    vertexBuffer: *mach.gpu.Buffer,
    pipeline: *mach.gpu.RenderPipeline,

    pub fn release(self: *RenderContext) void {
        self.pipeline.release();
    }
};

pub fn createRenderPipeline() RenderContext {
    const device = mach.core.device;

    // 编译 shader
    const source = @embedFile("shader.wgsl");
    const module = device.createShaderModuleWGSL("shader.wgsl", source);
    defer module.release();

    // 顶点着色器状态
    const vertex = mach.gpu.VertexState.init(.{
        .module = module,
        .entry_point = "vs_main",
        .buffers = &.{mach.gpu.VertexBufferLayout.init(.{
            // 分组，两个 f32 为一组传给顶点着色器
            .array_stride = @sizeOf(mesh.Vertex),
            .attributes = &.{
                // 格式和偏移，还有位置
                .{ .shader_location = 0, .format = .float32x4, .offset = 0 },
            },
        })},
    });

    // 片段着色器状态
    const fragment = mach.gpu.FragmentState.init(.{
        .module = module,
        .entry_point = "fs_main",
        .targets = &.{.{ .format = mach.core.descriptor.format }},
    });

    // 创建渲染管线
    const descriptor = mach.gpu.RenderPipeline.Descriptor{
        .fragment = &fragment,
        .vertex = vertex,
    };

    const pipeline = device.createRenderPipeline(&descriptor);

    const vertexBuffer = device.createBuffer(&.{
        .usage = .{ .vertex = true, .copy_dst = true },
        .size = @sizeOf(mesh.Vertex) * mesh.vertices.len,
        .mapped_at_creation = .true,
    });
    mach.core.queue.writeBuffer(vertexBuffer, 0, mesh.vertices);

    return RenderContext{
        .vertexBuffer = vertexBuffer,
        .pipeline = pipeline,
    };
}
