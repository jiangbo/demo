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

var msg: gfx.Texture = undefined;
var face: gfx.Texture = undefined;

var playerCamera: *gfx.Camera = undefined;

pub fn init(camera: *gfx.Camera) void {
    players[0] = .init("assets/r1.png", 0);
    players[1] = .init("assets/r2.png", 1);
    players[2] = .init("assets/r3.png", 2);

    msg = gfx.loadTexture("assets/msg.png", .init(790, 163));
    face = gfx.loadTexture("assets/face1_1.png", .init(307, 355));
    playerCamera = camera;

    map.init();
}

pub fn enter() void {
    playerCamera.lookAt(position);
    window.playMusic("assets/1.ogg");
}

pub fn exit() void {
    playerCamera.lookAt(.zero);
    window.stopMusic();
}

pub fn update(delta: f32) void {
    velocity = .zero;
    keyPressed = false;

    if (window.isAnyKeyDown(&.{ .UP, .W })) updatePlayer(.up);
    if (window.isAnyKeyDown(&.{ .DOWN, .S })) updatePlayer(.down);
    if (window.isAnyKeyDown(&.{ .LEFT, .A })) updatePlayer(.left);
    if (window.isAnyKeyDown(&.{ .RIGHT, .D })) updatePlayer(.right);

    if (window.isKeyRelease(.TAB)) {
        currentPlayer = &players[(currentPlayer.index + 1) % players.len];
    }

    if (velocity.approx(.zero)) {
        currentPlayer.current(facing).reset();
    } else {
        velocity = velocity.normalize().scale(delta * PLAYER_SPEED);
        const tempPosition = position.add(velocity);
        if (map.canWalk(tempPosition)) position = tempPosition;
        playerCamera.lookAt(position);
    }

    if (keyPressed) currentPlayer.current(facing).update(delta);

    for (map.npcSlice()) |*npc| {
        if (npc.area.contains(position)) {
            if (npc.keyTrigger) {
                if (window.isKeyRelease(.SPACE)) npc.action();
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

pub fn render(camera: *gfx.Camera) void {
    map.drawBackground(camera);

    var playerNotDraw: bool = true;
    for (map.npcSlice()) |npc| {
        if (npc.position.y > position.y and playerNotDraw) {
            drawPlayer(camera);
            playerNotDraw = false;
        }

        const npcPosition = npc.position.sub(PLAYER_OFFSET);

        if (npc.animation != null and !npc.animation.?.finished()) {
            camera.draw(npc.animation.?.currentTexture(), npcPosition);
        } else if (npc.texture) |texture| {
            camera.draw(texture, npcPosition);
        }

        // camera.drawRectangle(npc.area);
    }

    if (playerNotDraw) drawPlayer(camera);

    map.drawForeground(camera);

    camera.lookAt(.zero);
    camera.draw(msg, .init(0, 415));
    camera.draw(face, .init(0, 245));
    camera.lookAt(position);

    window.showFrameRate();
}

fn drawPlayer(camera: *gfx.Camera) void {
    const playerTexture = currentPlayer.current(facing).currentTexture();
    camera.draw(playerTexture, position.sub(PLAYER_OFFSET));
}
