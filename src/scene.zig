const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");
const cache = @import("cache.zig");

const SPEED = 100;
var position: math.Vector = .zero;
var facing: math.FourDirection = .down;

var upAnimation: gfx.FrameAnimation = undefined;
var downAnimation: gfx.FrameAnimation = undefined;
var leftAnimation: gfx.FrameAnimation = undefined;
var rightAnimation: gfx.FrameAnimation = undefined;

var roleTexture: gfx.Texture = undefined;

pub fn init() void {
    roleTexture = cache.loadTexture("assets/r1.png", .init(960, 960));

    const size: math.Vector = .init(960, 240);
    const upTexture = roleTexture.sub(.init(.{ .y = 720 }, size));
    upAnimation = .init("up", upTexture, 4);
    upAnimation.timer = .init(0.25);

    const downTexture = roleTexture.sub(.init(.{ .y = 0 }, size));
    downAnimation = .init("down", downTexture, 4);
    downAnimation.timer = .init(0.25);

    const leftTexture = roleTexture.sub(.init(.{ .y = 240 }, size));
    leftAnimation = .init("left", leftTexture, 4);
    leftAnimation.timer = .init(0.25);

    const rightTexture = roleTexture.sub(.init(.{ .y = 480 }, size));
    rightAnimation = .init("right", rightTexture, 4);
    rightAnimation.timer = .init(0.25);
}

pub fn update(delta: f32) void {
    updatePlayer(delta);

    switch (facing) {
        .up => upAnimation.update(delta),
        .down => downAnimation.update(delta),
        .left => leftAnimation.update(delta),
        .right => rightAnimation.update(delta),
    }
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

    switch (facing) {
        .up => gfx.draw(upAnimation.current(), position),
        .down => gfx.draw(downAnimation.current(), position),
        .left => gfx.draw(leftAnimation.current(), position),
        .right => gfx.draw(rightAnimation.current(), position),
    }
}
