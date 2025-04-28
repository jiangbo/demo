const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");
const assets = @import("assets.zig");

const FrameAnimation = gfx.FixedFrameAnimation(4, 0.25);

const SPEED = 100;
var position: math.Vector = .zero;
var facing: math.FourDirection = .down;

var upAnimation: FrameAnimation = undefined;
var downAnimation: FrameAnimation = undefined;
var leftAnimation: FrameAnimation = undefined;
var rightAnimation: FrameAnimation = undefined;

var roleTexture: gfx.Texture = undefined;

pub fn init() void {
    roleTexture = assets.loadTexture("assets/r1.png", .init(960, 960));

    const size: math.Vector = .init(960, 240);
    upAnimation = .init(roleTexture.subTexture(.init(.{ .y = 720 }, size)));

    downAnimation = .init(roleTexture.subTexture(.init(.{ .y = 0 }, size)));

    leftAnimation = .init(roleTexture.subTexture(.init(.{ .y = 240 }, size)));

    rightAnimation = .init(roleTexture.subTexture(.init(.{ .y = 480 }, size)));
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
