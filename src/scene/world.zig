const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");

pub const Player = @import("Player.zig");
pub const map = @import("map.zig");

const Dialog = struct {
    var background: gfx.Texture = undefined;
    face: gfx.Texture = undefined,
    left: bool = true,
    npc: *map.NPC = undefined,
};

pub var players: [3]Player = undefined;
pub var currentPlayer: *Player = &players[0];
pub var playerCamera: *gfx.Camera = undefined;

var dialog: ?Dialog = null;
var face: gfx.Texture = undefined;

pub fn init(camera: *gfx.Camera) void {
    players[0] = .init("assets/r1.png", 0);
    players[1] = .init("assets/r2.png", 1);
    players[2] = .init("assets/r3.png", 2);

    Dialog.background = gfx.loadTexture("assets/msg.png", .init(790, 163));
    face = gfx.loadTexture("assets/face1_1.png", .init(307, 355));
    playerCamera = camera;

    map.init();
}

pub fn enter() void {
    playerCamera.lookAt(Player.position);
    window.playMusic("assets/1.ogg");
}

pub fn exit() void {
    playerCamera.lookAt(.zero);
    window.stopMusic();
}

pub fn update(delta: f32) void {
    if (dialog) |*d| {
        if (window.isKeyRelease(.SPACE)) {
            if (d.left) d.left = false else dialog = null;
        }
        return;
    }

    currentPlayer.update(delta);

    for (map.npcSlice()) |*npc| {
        if (npc.area.contains(Player.position)) {
            if (npc.keyTrigger) {
                if (window.isKeyRelease(.SPACE)) npc.action();
            } else npc.action();
        }

        map.updateNpc(npc, delta);
    }
}

pub fn render(camera: *gfx.Camera) void {
    map.drawBackground(camera);

    var playerNotDraw: bool = true;
    for (map.npcSlice()) |npc| {
        if (npc.position.y > Player.position.y and playerNotDraw) {
            currentPlayer.render(camera);
            playerNotDraw = false;
        }

        const npcPosition = npc.position.sub(.init(120, 220));

        if (npc.animation != null and !npc.animation.?.finished()) {
            camera.draw(npc.animation.?.currentTexture(), npcPosition);
        } else if (npc.texture) |texture| {
            camera.draw(texture, npcPosition);
        }

        // camera.drawRectangle(npc.area);
    }

    if (playerNotDraw) currentPlayer.render(camera);

    map.drawForeground(camera);

    if (dialog) |d| {
        camera.lookAt(.zero);
        camera.draw(Dialog.background, .init(0, 415));
        if (d.left) {
            camera.draw(d.face, .init(0, 245));
        } else {
            camera.draw(d.npc.face.?, .init(486, 245));
        }
        camera.lookAt(Player.position);
    }
    window.showFrameRate();
}

pub fn showDialog(npc: *map.NPC) void {
    dialog = Dialog{ .face = face, .npc = npc };
}
