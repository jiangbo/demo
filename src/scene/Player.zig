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
roleTexture: gfx.Texture,
upAnimation: FrameAnimation = undefined,
downAnimation: FrameAnimation = undefined,
leftAnimation: FrameAnimation = undefined,
rightAnimation: FrameAnimation = undefined,

statusTexture: gfx.Texture = undefined,
attack: ?gfx.Texture = null,
defend: ?gfx.Texture = null,

pub fn init(index: u8) Player {
    var player = switch (index) {
        0 => initPlayer1(),
        1 => initPlayer2(),
        2 => initPlayer3(),
        else => unreachable,
    };

    const size: gfx.Vector = .init(960, 240);

    var area = gfx.Rectangle.init(.{ .y = 720 }, size);
    player.upAnimation = .init(player.roleTexture.subTexture(area));

    area = gfx.Rectangle.init(.{ .y = 0 }, size);
    player.downAnimation = .init(player.roleTexture.subTexture(area));

    area = gfx.Rectangle.init(.{ .y = 240 }, size);
    player.leftAnimation = .init(player.roleTexture.subTexture(area));

    area = gfx.Rectangle.init(.{ .y = 480 }, size);
    player.rightAnimation = .init(player.roleTexture.subTexture(area));

    return player;
}

fn initPlayer1() Player {
    const role = window.loadTexture("assets/r1.png", .init(960, 960));
    return Player{
        .index = 0,
        .roleTexture = role,
        .statusTexture = window.loadTexture("assets/item/face1.png", .init(357, 317)),
        .attack = window.loadTexture("assets/item/item3.png", .init(66, 66)),
        .defend = window.loadTexture("assets/item/item5.png", .init(66, 66)),
    };
}

fn initPlayer2() Player {
    const role = window.loadTexture("assets/r2.png", .init(960, 960));

    return Player{
        .index = 1,
        .roleTexture = role,
        .statusTexture = window.loadTexture("assets/item/face2.png", .init(357, 317)),
    };
}

fn initPlayer3() Player {
    const role = window.loadTexture("assets/r3.png", .init(960, 960));
    return Player{
        .index = 2,
        .roleTexture = role,
        .statusTexture = window.loadTexture("assets/item/face3.png", .init(357, 317)),
    };
}

pub fn update(self: *Player, delta: f32) void {
    velocity = .zero;
    keyPressed = false;

    if (world.mouseTarget) |target| {
        velocity = target.sub(position).normalize();
        if (@abs(velocity.x) > @abs(velocity.y)) {
            facing = if (velocity.x > 0) .right else .left;
        } else {
            facing = if (velocity.y > 0) .down else .up;
        }
        keyPressed = true;
        const distance = target.sub(position);
        if (@abs(distance.x) < 16 and @abs(distance.y) < 16) {
            velocity = .zero;
            world.mouseTarget = null;
        }
    }

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
    world.mouseTarget = null;
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
