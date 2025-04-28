const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");
const cache = @import("cache.zig");

const SPEED = 100;
var position: math.Vector = .zero;
var facing: math.FourDirection = .down;

var upTexture: gfx.Texture = undefined;
var downTexture: gfx.Texture = undefined;
var leftTexture: gfx.Texture = undefined;
var rightTexture: gfx.Texture = undefined;

var roleTexture: gfx.Texture = undefined;

pub fn init() void {
    roleTexture = cache.loadTexture("assets/r1.png", .init(960, 960));

    const size: math.Vector = .init(240, 240);
    upTexture = roleTexture.sub(.init(.{ .y = 720 }, size));
    downTexture = roleTexture.sub(.init(.{ .y = 0 }, size));
    leftTexture = roleTexture.sub(.init(.{ .y = 240 }, size));
    rightTexture = roleTexture.sub(.init(.{ .y = 480 }, size));
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
