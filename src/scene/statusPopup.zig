const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");

pub var display: bool = false;
var position: gfx.Vector = undefined;
var background: gfx.Texture = undefined;

pub fn init() void {
    position = .init(60, 60);
    background = gfx.loadTexture("assets/item/status_bg.png", .init(677, 428));
}

pub fn update(delta: f32) void {
    if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E })) display = false;

    _ = delta;
}

pub fn render(camera: *gfx.Camera) void {
    if (!display) return;

    camera.draw(background, position);
}
