const std = @import("std");

const mach = @import("mach");

pub const App = @This();

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
renderPipeline: *mach.gpu.RenderPipeline = undefined,
bindGroup: *mach.gpu.BindGroup = undefined,

pub fn init(app: *App) !void {
    try mach.core.init(.{});
    // 设置帧率
    mach.core.setFrameRateLimit(30);
    mach.core.setInputFrequency(30);

    const device = mach.core.device;

    const red: u32 = 0xFF0000FF;
    const yellow: u32 = 0xFFFF00FF;
    const blue: u32 = 0x0000FFFF;

    const textureData = [_]u32{
        blue, red,    red,    red,    red, //
        red,  yellow, yellow, yellow, red,
        red,  yellow, red,    red,    red,
        red,  yellow, yellow, red,    red,
        red,  yellow, red,    red,    red,
        red,  yellow, red,    red,    red,
        red,  red,    red,    red,    red,
    };

    const size = mach.gpu.Extent3D{ .width = 5, .height = 7 };
    const texture = device.createTexture(&.{
        .label = "F texutre",
        .size = .{ .width = size.width, .height = size.height },
        .format = .rgba8_unorm,
        .usage = .{ .texture_binding = true, .copy_dst = true, .render_attachment = true },
    });

    device.getQueue().writeTexture(&.{ .texture = texture }, &.{
        .bytes_per_row = @sizeOf(u32) * 5,
        .rows_per_image = 7,
    }, &size, &textureData);

    const sampler = device.createSampler(null);
    app.renderPipeline = createRenderPipeline();
    app.bindGroup = device.createBindGroup(&.{
        .layout = app.renderPipeline.getBindGroupLayout(0),
        .entry_count = 2,
        .entries = (&[2]mach.gpu.BindGroup.Entry{
            mach.gpu.BindGroup.Entry.sampler(0, sampler),
            mach.gpu.BindGroup.Entry.textureView(1, texture.createView(null)),
        }),
    });
}

fn createRenderPipeline() *mach.gpu.RenderPipeline {
    const device = mach.core.device;

    // 编译 shader
    const source = @embedFile("shader/shader.wgsl");
    const module = device.createShaderModuleWGSL("shader.wgsl", source);
    defer module.release();

    // 片段着色器状态
    const fragment = mach.gpu.FragmentState.init(.{
        .module = module,
        .entry_point = "fs_main",
        .targets = &.{.{ .format = mach.core.descriptor.format }},
    });

    // 创建渲染管线
    const descriptor = mach.gpu.RenderPipeline.Descriptor{
        .fragment = &fragment,
        .vertex = .{ .module = module, .entry_point = "vs_main" },
    };
    return device.createRenderPipeline(&descriptor);
}

pub fn deinit(app: *App) void {
    _ = app;
    mach.core.deinit();
    _ = gpa.deinit();
}

pub fn update(app: *App) !bool {
    // 检查窗口是否需要关闭
    var iterator = mach.core.pollEvents();
    while (iterator.next()) |event| if (event == .close) return true;

    // 清屏使用
    const view = mach.core.swap_chain.getCurrentTextureView().?;
    const colorAttachment = mach.gpu.RenderPassColorAttachment{
        .view = view,
        .clear_value = std.mem.zeroes(mach.gpu.Color),
        .load_op = .clear,
        .store_op = .store,
    };

    const renderPass = mach.gpu.RenderPassDescriptor.init(.{
        .color_attachments = &.{colorAttachment},
    });

    // 命令编码器
    const encoder = mach.core.device.createCommandEncoder(null);
    const pass = encoder.beginRenderPass(&renderPass);

    // 设置渲染管线
    pass.setPipeline(app.renderPipeline);
    pass.setBindGroup(0, app.bindGroup, null);
    // 六个点，画两个三角形
    pass.draw(6, 2, 0, 0);
    pass.end();
    pass.release();

    var command = encoder.finish(null);
    encoder.release();

    // 提交命令
    mach.core.queue.submit(&.{command});
    command.release();
    mach.core.swap_chain.present();
    view.release();

    // 不退出渲染循环
    return false;
}
