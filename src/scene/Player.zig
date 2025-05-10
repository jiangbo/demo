const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const world = @import("world.zig");

const Player = @This();
const FrameAnimation = gfx.FixedFrameAnimation(4, 0.15);
const PLAYER_SPEED = 150;
const PlayerState = enum { walk, talk };

pub var position: gfx.Vector = .init(800, 500);
pub var state: PlayerState = .walk;
var facing: gfx.FourDirection = .down;
var keyPressed: bool = false;
var velocity: gfx.Vector = .zero;

index: u8,
upAnimation: FrameAnimation,
downAnimation: FrameAnimation,
leftAnimation: FrameAnimation,
rightAnimation: FrameAnimation,

pub fn init(path: [:0]const u8, index: u8) Player {
    const role = window.loadTexture(path, .init(960, 960));
    const size: gfx.Vector = .init(960, 240);

    return Player{
        .index = index,
        .upAnimation = .init(role.subTexture(.init(.{ .y = 720 }, size))),
        .downAnimation = .init(role.subTexture(.init(.{ .y = 0 }, size))),
        .leftAnimation = .init(role.subTexture(.init(.{ .y = 240 }, size))),
        .rightAnimation = .init(role.subTexture(.init(.{ .y = 480 }, size))),
    };
}

pub fn update(self: *Player, delta: f32) void {
    velocity = .zero;
    keyPressed = false;

    if (window.isAnyKeyDown(&.{ .UP, .W })) updatePlayer(.up);
    if (window.isAnyKeyDown(&.{ .DOWN, .S })) updatePlayer(.down);
    if (window.isAnyKeyDown(&.{ .LEFT, .A })) updatePlayer(.left);
    if (window.isAnyKeyDown(&.{ .RIGHT, .D })) updatePlayer(.right);

    if (window.isKeyRelease(.TAB)) {
        const playerIndex = (self.index + 1) % world.players.len;
        world.currentPlayer = &world.players[playerIndex];
    }

    if (velocity.approx(.zero)) {
        self.current(facing).reset();
    } else {
        velocity = velocity.normalize().scale(delta * PLAYER_SPEED);
        const tempPosition = position.add(velocity);
        if (world.map.canWalk(tempPosition)) position = tempPosition;
        world.playerCamera.lookAt(position);
    }

    if (keyPressed) self.current(facing).update(delta);
}

fn updatePlayer(direction: gfx.FourDirection) void {
    facing = direction;
    keyPressed = true;
    velocity = velocity.add(direction.toVector());
}

pub fn render(self: *Player, camera: *gfx.Camera) void {
    const playerTexture = self.current(facing).currentTexture();
    camera.draw(playerTexture, position.sub(.init(120, 220)));
}

fn current(self: *Player, face: gfx.FourDirection) *FrameAnimation {
    return switch (face) {
        .up => &self.upAnimation,
        .down => &self.downAnimation,
        .left => &self.leftAnimation,
        .right => &self.rightAnimation,
    };
}
