const std = @import("std");
const mach = @import("mach");

pub const App = @This();
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn init(_: *App) !void {
    try mach.core.init(.{
        .size = .{ .width = 800, .height = 600 },
        .title = "学习 WebGPU",
    });
}

pub fn deinit(_: *App) void {
    defer _ = gpa.deinit();
    defer mach.core.deinit();
}

pub fn update(_: *App) !bool {
    var iterator = mach.core.pollEvents();
    while (iterator.next()) |event| if (event == .close) return true;

    const view = mach.core.swap_chain.getCurrentTextureView().?;
    const colorAttachment = mach.gpu.RenderPassColorAttachment{
        .view = view,
        .clear_value = mach.gpu.Color{ .r = 0, .g = 0, .b = 0, .a = 1.0 },
        .load_op = .clear,
        .store_op = .store,
    };

    const encoder = mach.core.device.createCommandEncoder(null);
    const renderPass = mach.gpu.RenderPassDescriptor.init(.{
        .color_attachments = &.{colorAttachment},
    });

    const pass = encoder.beginRenderPass(&renderPass);
    pass.end();
    pass.release();

    var command = encoder.finish(null);
    encoder.release();

    var queue = mach.core.queue;
    queue.submit(&[_]*mach.gpu.CommandBuffer{command});
    command.release();
    mach.core.swap_chain.present();
    view.release();
    return false;
}
