const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");

const SPEED = 100;
var position: math.Vector = .zero;

pub fn init() void {}

pub fn update(delta: f32) void {
    updatePlayer(delta);
}

fn updatePlayer(delta: f32) void {
    var velocity: math.Vector = .zero;

    if (window.isKeyDown(.UP) or window.isKeyDown(.W))
        velocity.selfAdd(.{ .y = -1 });
    if (window.isKeyDown(.DOWN) or window.isKeyDown(.S))
        velocity.selfAdd(.{ .y = 1 });
    if (window.isKeyDown(.LEFT) or window.isKeyDown(.A))
        velocity.selfAdd(.{ .x = -1 });
    if (window.isKeyDown(.RIGHT) or window.isKeyDown(.D))
        velocity.selfAdd(.{ .x = 1 });

    if (!velocity.approx(.zero)) {
        position.selfAdd(velocity.normalize().scale(delta * SPEED));
    }
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    gfx.draw(gfx.loadTexture("assets/role.png"), position);
}
