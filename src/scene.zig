const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");

pub fn init() void {}

pub fn event(ev: *const window.Event) void {
    _ = ev;
}
pub fn update(delta: f32) void {
    _ = delta;
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();
}

pub fn deinit() void {}
