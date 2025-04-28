const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");
const assets = @import("assets.zig");

const Player = @import("Player.zig");
const PLAYER_SPEED = 100;

var players: [3]Player = undefined;
var currentPlayer: *Player = &players[0];
var position: math.Vector = .zero;
var facing: math.FourDirection = .down;
var keyPressed: bool = false;

pub fn init() void {
    players[0] = .init("assets/r1.png", 0);
    players[1] = .init("assets/r2.png", 1);
    players[2] = .init("assets/r3.png", 2);
}

pub fn event(ev: *const window.Event) void {
    if (ev.type == .KEY_UP and ev.key_code == .TAB) {
        currentPlayer = &players[(currentPlayer.index + 1) % players.len];
    }
}

pub fn update(delta: f32) void {
    updatePlayer(delta);

    if (keyPressed) currentPlayer.current(facing).update(delta);
}

fn updatePlayer(delta: f32) void {
    var velocity: math.Vector = .zero;
    keyPressed = false;

    if (window.isKeyDown(.UP) or window.isKeyDown(.W)) {
        facing = .up;
        velocity = velocity.add(facing.toVector());
        keyPressed = true;
    }

    if (window.isKeyDown(.DOWN) or window.isKeyDown(.S)) {
        facing = .down;
        velocity = velocity.add(facing.toVector());
        keyPressed = true;
    }

    if (window.isKeyDown(.LEFT) or window.isKeyDown(.A)) {
        facing = .left;
        velocity = velocity.add(facing.toVector());
        keyPressed = true;
    }

    if (window.isKeyDown(.RIGHT) or window.isKeyDown(.D)) {
        facing = .right;
        velocity = velocity.add(facing.toVector());
        keyPressed = true;
    }

    if (!velocity.approx(.zero)) {
        velocity = velocity.normalize().scale(delta * PLAYER_SPEED);
        position = position.add(velocity);
    }
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    gfx.draw(currentPlayer.current(facing).current(), position);
}
