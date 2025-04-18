const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");

const cursor = @import("cursor.zig");

pub fn init() void {
    window.showCursor(false);
    audio.playMusic("assets/bgm.ogg");
}

pub fn event(ev: *const window.Event) void {
    cursor.event(ev);
}
pub fn update(delta: f32) void {
    _ = delta;
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    gfx.draw(gfx.loadTexture("assets/background.png"), .zero);
    cursor.render();
}

pub fn deinit() void {
    window.showCursor(true);
    audio.stopMusic();
}
