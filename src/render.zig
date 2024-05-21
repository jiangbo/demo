const std = @import("std");
const mach = @import("mach");

pub const RenderContext = struct {
    bindGroup: *mach.gpu.BindGroup,
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

    const vertex = mach.gpu.VertexState.init(.{
        .module = module,
        .entry_point = "vs_main",
    });

    // 片段着色器状态
    const fragment = mach.gpu.FragmentState.init(.{
        .module = module,
        .entry_point = "fs_main",
        .targets = &.{.{ .format = mach.core.descriptor.format }},
    });

    const width = 5;
    const height = 7;
    const r: u32 = 0xFF0000FF;
    const y: u32 = 0xFF00FFFF;
    const b: u32 = 0xFFFF0000;
    // mach.gpu.color
    const textureData = [_]u32{
        b, r, r, r, r,
        r, y, y, y, r,
        r, y, r, r, r,
        r, y, y, r, r,
        r, y, r, r, r,
        r, y, r, r, r,
        r, r, r, r, r,
    };

    const texture = device.createTexture(&.{
        .label = "F texture",
        .size = .{ .width = width, .height = height },
        .format = .rgba8_unorm,
        .usage = .{ .texture_binding = true, .copy_dst = true },
    });

    const layout = mach.gpu.Texture.DataLayout{
        .bytes_per_row = width * 4,
        .rows_per_image = height,
    };
    const size = mach.gpu.Extent3D{ .width = width, .height = height };
    device.getQueue().writeTexture(&.{ .texture = texture }, &layout, &size, &textureData);

    const sampler = device.createSampler(&.{});

    // 创建渲染管线
    const descriptor = mach.gpu.RenderPipeline.Descriptor{
        .fragment = &fragment,
        .vertex = vertex,
    };

    const pipeline = device.createRenderPipeline(&descriptor);

    const view = texture.createView(&.{
        .format = .rgba8_unorm,
        .dimension = .dimension_2d,
        .aspect = .all,
        .base_mip_level = 0,
        .mip_level_count = 1,
        .base_array_layer = 0,
        .array_layer_count = 1,
    });
    const bindGroup = device.createBindGroup(
        &mach.gpu.BindGroup.Descriptor.init(.{
            .layout = pipeline.getBindGroupLayout(0),
            .entries = &.{
                mach.gpu.BindGroup.Entry.sampler(0, sampler),
                mach.gpu.BindGroup.Entry.textureView(1, view),
            },
        }),
    );

    return .{
        .bindGroup = bindGroup,
        .pipeline = pipeline,
    };
}
