const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");

const SPEED = 100;
var position: math.Vector = .zero;
var facing: math.FourDirection = .down;

pub fn init() void {}

pub fn update(delta: f32) void {
    updatePlayer(delta);
}

fn updatePlayer(delta: f32) void {
    var velocity: math.Vector = .zero;

    if (window.isKeyDown(.UP) or window.isKeyDown(.W)) {
        velocity = velocity.add(.{ .y = -1 });
        facing = .up;
    }

    if (window.isKeyDown(.DOWN) or window.isKeyDown(.S)) {
        velocity = velocity.add(.{ .y = 1 });
        facing = .down;
    }

    if (window.isKeyDown(.LEFT) or window.isKeyDown(.A)) {
        velocity = velocity.add(.{ .x = -1 });
        facing = .left;
    }

    if (window.isKeyDown(.RIGHT) or window.isKeyDown(.D)) {
        velocity = velocity.add(.{ .x = 1 });
        facing = .right;
    }

    if (!velocity.approx(.zero)) {
        velocity = velocity.normalize().scale(delta * SPEED);
        position = position.add(velocity);
    }
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    gfx.draw(gfx.loadTexture("assets/role.png"), position);
}
