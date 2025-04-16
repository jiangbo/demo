const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");

pub fn init() void {
    // gfx.camera.rect.size = window.size;
}

pub fn event(ev: *const window.Event) void {
    _ = ev;
}
pub fn update(delta: f32) void {
    _ = delta;
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    const background = gfx.loadTexture("assets/background.png");
    gfx.draw(background, window.size.sub(background.size()).scale(0.5));
}

pub fn deinit() void {}
