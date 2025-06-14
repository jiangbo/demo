const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const camera = @import("../camera.zig");

var playerTexture: gfx.Texture = undefined;
pub fn init() void {
    playerTexture = gfx.loadTexture("assets/pic/player.png", .init(96, 192));
}

pub fn enter() void {}

pub fn exit() void {}

pub fn update(delta: f32) void {
    _ = delta;
}

pub fn render() void {
    camera.draw(playerTexture, .init(100, 100));
}
