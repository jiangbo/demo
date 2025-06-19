const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const camera = @import("../camera.zig");

var playerTexture: gfx.Texture = undefined;
var map: gfx.Texture = undefined;
pub fn init() void {
    playerTexture = gfx.loadTexture("assets/pic/player.png", .init(96, 192));
    map = gfx.loadTexture("assets/pic/maps.png", .init(640, 1536));
}

pub fn update(delta: f32) void {
    _ = delta;
}

pub fn enter() void {}

pub fn exit() void {}

pub fn render() void {
    camera.draw(map, .zero);
    camera.draw(playerTexture, .init(100, 100));
}
