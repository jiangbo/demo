const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");

var background1: gfx.Texture = undefined;

pub fn init() void {
    background1 = gfx.loadTexture("assets/T_bg1.png", .init(800, 600));
}

pub fn update(delta: f32) void {
    std.log.info("update title", .{});
    _ = delta;
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    gfx.draw(background1, .zero);
}
