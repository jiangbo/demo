const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const world = @import("world.zig");

pub var display: bool = false;
var position: gfx.Vector = undefined;
var background: gfx.Texture = undefined;
var selectedPlayer: usize = 0;

pub fn init() void {
    position = .init(58, 71);
    background = gfx.loadTexture("assets/item/status_bg.png", .init(677, 428));
}

pub fn update(delta: f32) void {
    if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E })) display = false;

    if (window.isAnyKeyRelease(&.{ .LEFT, .A })) {
        selectedPlayer += world.players.len;
        selectedPlayer = (selectedPlayer - 1) % world.players.len;
    } else if (window.isAnyKeyRelease(&.{ .RIGHT, .D })) {
        selectedPlayer = (selectedPlayer + 1) % world.players.len;
    }

    _ = delta;
}

pub fn render(camera: *gfx.Camera) void {
    if (!display) return;

    camera.draw(background, position);
    const statusTexture = world.players[selectedPlayer].statusTexture;
    camera.draw(statusTexture, position);
}
