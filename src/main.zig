const std = @import("std");

const gfx = @import("graphics.zig");
const window = @import("window.zig");
const scene = @import("scene.zig");

pub fn init() void {
    scene.init();
}

pub fn event(ev: *const window.Event) void {
    scene.currentScene.event(ev);
}

pub fn update() void {
    scene.currentScene.update();
}

pub fn render() void {
    var passEncoder = gfx.CommandEncoder.beginRenderPass(.{ .r = 1, .b = 1, .a = 1.0 });
    defer passEncoder.submit();
    scene.currentScene.render();
}

pub fn deinit() void {
    scene.deinit();
}

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    window.width = 1280;
    window.height = 720;

    window.run(.{
        .title = "植物明星大乱斗",
        .init = init,
        .event = event,
        .update = update,
        .render = render,
        .deinit = deinit,
    });
}
