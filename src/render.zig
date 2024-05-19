const std = @import("std");
const mach = @import("mach");

pub const RenderContext = struct {
    vertexBuffer: *mach.gpu.Buffer,
    indexBuffer: *mach.gpu.Buffer,
    pipeline: *mach.gpu.RenderPipeline,

    pub fn release(self: *RenderContext) void {
        self.vertexBuffer.release();
        self.indexBuffer.release();
        self.pipeline.release();
    }
};

pub const vertexData = [_]f32{
    // left column
    0,   0,   0,
    30,  0,   0,
    0,   150, 0,
    30,  150, 0,

    // top rung
    30,  0,   0,
    100, 0,   0,
    30,  30,  0,
    100, 30,  0,

    // middle rung
    30,  60,  0,
    70,  60,  0,
    30,  90,  0,
    70,  90,  0,
};

pub const indexData = [_]u32{
    0, 1, 2, 2, 1, 3, // left column
    4, 5, 6, 6, 5, 7, // top run
    8, 9, 10, 10, 9, 11, // middle run
};

pub fn createRenderPipeline() RenderContext {
    const device = mach.core.device;

    // 编译 shader
    const source = @embedFile("shader.wgsl");
    const module = device.createShaderModuleWGSL("shader.wgsl", source);
    defer module.release();

    // 顶点缓冲区
    const vertexBuffer = device.createBuffer(&.{
        .label = "vertex",
        .usage = .{ .copy_dst = true, .vertex = true },
        .size = @sizeOf(@TypeOf(vertexData)),
    });

    // 索引缓冲区
    const indexBuffer = device.createBuffer(&.{
        .label = "index",
        .size = @sizeOf(@TypeOf(indexData)),
        .usage = .{ .index = true, .copy_dst = true },
    });

    // 将 CPU 内存中的数据复制到 GPU 内存中
    mach.core.queue.writeBuffer(vertexBuffer, 0, &vertexData);
    mach.core.queue.writeBuffer(indexBuffer, 0, &indexData);

    const vertexLayout = mach.gpu.VertexBufferLayout.init(.{
        .array_stride = @sizeOf(f32) * 3,
        .attributes = &.{
            .{ .format = .float32x3, .offset = 0, .shader_location = 0 },
        },
    });

    const vertex = mach.gpu.VertexState.init(.{
        .module = module,
        .entry_point = "vs_main",
        .buffers = &.{vertexLayout},
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
    return .{
        .vertexBuffer = vertexBuffer,
        .indexBuffer = indexBuffer,
        .pipeline = pipeline,
    };
}
