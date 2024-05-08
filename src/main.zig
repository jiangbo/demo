const std = @import("std");
const mach = @import("mach");

pub const App = @This();

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
renderPipeline: *mach.gpu.RenderPipeline,
timer: mach.core.Timer,

pub fn init(app: *App) !void {
    try mach.core.init(.{
        .size = .{ .width = 800, .height = 600 },
        .title = "学习 WebGPU",
    });

    const device = mach.core.device;
    const source = @embedFile("shader/shader.wgsl");
    const shader = device.createShaderModuleWGSL("shader.wgsl", source);
    defer shader.release();

    const fragment = mach.gpu.FragmentState.init(.{
        .module = shader,
        .entry_point = "fragment_main",
        .targets = &.{.{ .format = mach.core.descriptor.format }},
    });

    app.renderPipeline = device.createRenderPipeline(&.{
        .vertex = .{ .module = shader, .entry_point = "vertex_main" },
        .fragment = &fragment,
    });
    app.timer = try mach.core.Timer.start();
}

pub fn deinit(app: *App) void {
    defer _ = gpa.deinit();
    defer mach.core.deinit();
    defer app.renderPipeline.release();
}

pub fn update(app: *App) !bool {
    var iterator = mach.core.pollEvents();
    while (iterator.next()) |event| if (event == .close) return true;

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

    const encoder = mach.core.device.createCommandEncoder(null);
    const pass = encoder.beginRenderPass(&renderPass);
    pass.setPipeline(app.renderPipeline);
    pass.draw(3, 1, 0, 0);
    pass.end();
    pass.release();

    var command = encoder.finish(null);
    encoder.release();

    mach.core.queue.submit(&.{command});
    command.release();
    mach.core.swap_chain.present();
    view.release();

    // update the window title every second
    if (app.timer.read() >= 1.0) {
        app.timer.reset();
        try mach.core.printTitle("[ {d}fps ] [ Input {d}hz ]", .{
            mach.core.frameRate(),
            mach.core.inputRate(),
        });
    }

    return false;
}
