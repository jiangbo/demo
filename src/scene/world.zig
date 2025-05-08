const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");

const Player = @import("Player.zig");
const map = @import("map.zig");
const PLAYER_SPEED = 150;
const PLAYER_OFFSET: gfx.Vector = .init(120, 220);

var players: [3]Player = undefined;
var currentPlayer: *Player = &players[0];
pub var position: gfx.Vector = .init(100, 500);
var facing: gfx.FourDirection = .down;
var keyPressed: bool = false;
var velocity: gfx.Vector = .zero;

pub fn init() void {
    gfx.camera = .{ .rect = .init(.zero, window.size), .border = map.SIZE };
    gfx.camera.lookAt(position);

    players[0] = .init("assets/r1.png", 0);
    players[1] = .init("assets/r2.png", 1);
    players[2] = .init("assets/r3.png", 2);

    map.init();
}

pub fn update(delta: f32) void {
    velocity = .zero;
    keyPressed = false;

    if (window.isAnyKeyDown(&.{ .UP, .W })) updatePlayer(.up);
    if (window.isAnyKeyDown(&.{ .DOWN, .S })) updatePlayer(.down);
    if (window.isAnyKeyDown(&.{ .LEFT, .A })) updatePlayer(.left);
    if (window.isAnyKeyDown(&.{ .RIGHT, .D })) updatePlayer(.right);

    if (window.isRelease(.TAB)) {
        currentPlayer = &players[(currentPlayer.index + 1) % players.len];
    }

    if (velocity.approx(.zero)) {
        currentPlayer.current(facing).reset();
    } else {
        velocity = velocity.normalize().scale(delta * PLAYER_SPEED);
        const tempPosition = position.add(velocity);
        if (map.canWalk(tempPosition)) position = tempPosition;
        gfx.camera.lookAt(position);
    }

    if (keyPressed) currentPlayer.current(facing).update(delta);

    for (map.npcSlice()) |*npc| {
        if (npc.area.contains(position)) {
            if (npc.keyTrigger) {
                if (window.isRelease(.SPACE)) npc.action();
            } else npc.action();
        }

        map.updateNpc(npc, delta);
    }
}

fn updatePlayer(direction: gfx.FourDirection) void {
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

        const npcPosition = npc.position.sub(PLAYER_OFFSET);

        if (npc.animation != null and !npc.animation.?.finished()) {
            gfx.draw(npc.animation.?.currentTexture(), npcPosition);
        } else if (npc.texture) |texture| {
            gfx.draw(texture, npcPosition);
        }

        gfx.drawRectangle(npc.area);
    }

    if (playerNotDraw) drawPlayer();

    map.drawForeground();

    window.showFrameRate();
}

fn drawPlayer() void {
    const playerTexture = currentPlayer.current(facing).currentTexture();
    gfx.draw(playerTexture, position.sub(PLAYER_OFFSET));
}
