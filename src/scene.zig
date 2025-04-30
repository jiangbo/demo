const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");
const assets = @import("assets.zig");

const Player = @import("Player.zig");
const map = @import("map.zig");
const PLAYER_SPEED = 150;
const PLAYER_OFFSET: math.Vector = .init(120, 220);

var players: [3]Player = undefined;
var currentPlayer: *Player = &players[0];
var position: math.Vector = .init(800, 500);
var facing: math.FourDirection = .down;
var keyPressed: bool = false;
var velocity: math.Vector = .zero;

pub fn init() void {
    gfx.camera = .{ .rect = .init(.zero, window.size), .border = map.SIZE };
    gfx.camera.lookAt(position);

    players[0] = .init("assets/r1.png", 0);
    players[1] = .init("assets/r2.png", 1);
    players[2] = .init("assets/r3.png", 2);

    map.init();
}

pub fn event(ev: *const window.Event) void {
    if (ev.type == .KEY_UP and ev.key_code == .TAB) {
        currentPlayer = &players[(currentPlayer.index + 1) % players.len];
    }
}

pub fn update(delta: f32) void {
    velocity = .zero;
    keyPressed = false;

    if (window.isAnyKeyDown(&.{ .UP, .W })) updatePlayer(.up);
    if (window.isAnyKeyDown(&.{ .DOWN, .S })) updatePlayer(.down);
    if (window.isAnyKeyDown(&.{ .LEFT, .A })) updatePlayer(.left);
    if (window.isAnyKeyDown(&.{ .RIGHT, .D })) updatePlayer(.right);

    if (velocity.approx(.zero)) {
        currentPlayer.current(facing).reset();
    } else {
        velocity = velocity.normalize().scale(delta * PLAYER_SPEED);
        const tempPosition = position.add(velocity);
        if (map.canWalk(tempPosition)) position = tempPosition;
        gfx.camera.lookAt(position);
    }

    if (keyPressed) currentPlayer.current(facing).update(delta);

    if (window.isPressed(.SPACE)) {
        for (map.npcSlice()) |*npc| {
            if (npc.area.contains(position)) npc.action();
        }
    }
}

fn updatePlayer(direction: math.FourDirection) void {
    facing = direction;
    keyPressed = true;
    velocity = velocity.add(direction.toVector());
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    map.drawBackground();

    var playerNotDraw: bool = true;
    for (map.npcSlice()) |npc| {
        if (npc.position.y > position.y and playerNotDraw) {
            drawPlayer();
            playerNotDraw = false;
        }

        if (npc.texture) |texture| {
            gfx.draw(texture, npc.position.sub(PLAYER_OFFSET));
        }

        gfx.drawRectangle(npc.area);
    }

    if (playerNotDraw) drawPlayer();

    map.drawForeground();
}

fn drawPlayer() void {
    const playerTexture = currentPlayer.current(facing).currentTexture();
    gfx.draw(playerTexture, position.sub(PLAYER_OFFSET));
}
