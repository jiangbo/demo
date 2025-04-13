const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");

var animationDown1: gfx.SliceFrameAnimation = undefined;

pub fn init() void {
    animationDown1 = .load("assets/hajimi_idle_front_{}.png", 4);
}

pub fn deinit() void {}

pub fn event(ev: *const window.Event) void {
    _ = ev;
}

pub fn update(delta: f32) void {
    animationDown1.update(delta);
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    const background = gfx.loadTexture("assets/background.png");
    gfx.draw(background, 0, 0);

    gfx.playSlice(&animationDown1, .{ .x = 100, .y = 100 });
}
