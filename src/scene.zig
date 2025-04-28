const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");

const SPEED = 100;
var position: math.Vector = .zero;
var facing: math.FourDirection = .down;

var upTexture: gfx.Texture = undefined;
var downTexture: gfx.Texture = undefined;
var leftTexture: gfx.Texture = undefined;
var rightTexture: gfx.Texture = undefined;

pub fn init() void {
    upTexture = gfx.loadTexture("assets/role2.png");
    downTexture = gfx.loadTexture("assets/role.png");
    leftTexture = gfx.loadTexture("assets/role3.png");
    rightTexture = gfx.loadTexture("assets/role4.png");
}

pub fn update(delta: f32) void {
    updatePlayer(delta);
}

fn updatePlayer(delta: f32) void {
    var velocity: math.Vector = .zero;

    if (window.isKeyDown(.UP) or window.isKeyDown(.W)) {
        facing = .up;
        velocity = velocity.add(facing.toVector());
    }

    if (window.isKeyDown(.DOWN) or window.isKeyDown(.S)) {
        facing = .down;
        velocity = velocity.add(facing.toVector());
    }

    if (window.isKeyDown(.LEFT) or window.isKeyDown(.A)) {
        facing = .left;
        velocity = velocity.add(facing.toVector());
    }

    if (window.isKeyDown(.RIGHT) or window.isKeyDown(.D)) {
        facing = .right;
        velocity = velocity.add(facing.toVector());
    }

    if (!velocity.approx(.zero)) {
        velocity = velocity.normalize().scale(delta * SPEED);
        position = position.add(velocity);
    }
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    const current = switch (facing) {
        .up => upTexture,
        .down => downTexture,
        .left => leftTexture,
        .right => rightTexture,
    };

    gfx.draw(current, position);
}
