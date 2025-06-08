const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const world = @import("world.zig");
const camera = @import("../camera.zig");
const panel = @import("panel.zig");

pub const Enemy = struct {
    active: bool = false,
    texture: gfx.Texture = undefined,
};

const statusEnum = enum { idle, attack, hurt, dead, none };

var background: gfx.Texture = undefined;
var enemyTexture: gfx.Texture = undefined;
var enemies: [3]Enemy = undefined;
var targetTexture: gfx.Texture = undefined;

var attackTimer: window.Timer = .init(0.4);
pub var selected: usize = 0;

var areas: [6]gfx.Rectangle = .{
    .init(.init(497, 138), .init(240, 240)),
    .init(.init(575, 241), .init(240, 240)),
    .init(.init(468, 297), .init(240, 240)),
    .init(.init(93, 130), .init(480, 240)),
    .init(.init(19, 225), .init(480, 240)),
    .init(.init(60, 321), .init(480, 240)),
};
var textures: [areas.len]gfx.Texture = undefined;
pub var status = [1]statusEnum{.idle} ** areas.len;

pub fn init() void {
    background = gfx.loadTexture("assets/fight/f_scene.png", .init(800, 600));
    enemyTexture = gfx.loadTexture("assets/fight/enemy.png", .init(1920, 240));
    targetTexture = gfx.loadTexture("assets/fight/fm_b4_2.png", .init(190, 186));
    panel.init();
    attackTimer.stop();

    textures[0] = gfx.loadTexture("assets/fight/p1.png", .init(960, 240));
    textures[1] = gfx.loadTexture("assets/fight/p2.png", .init(960, 240));
    textures[2] = gfx.loadTexture("assets/fight/p3.png", .init(960, 240));
    textures[3] = gfx.loadTexture("assets/fight/enemy.png", .init(1920, 240));
    textures[4] = textures[3];
    textures[5] = textures[3];
}

pub fn enter() void {
    window.playMusic("assets/fight/fight.ogg");
}

pub fn exit() void {
    window.stopMusic();
}

pub fn startAttack(attack: usize, hurt: usize) void {
    attackTimer.reset();
    status[attack] = .attack;
    status[hurt] = .hurt;
}

pub fn update(delta: f32) void {
    if (attackTimer.isFinishedAfterUpdate(delta)) {
        for (&status) |*value| {
            if (value.* == .attack or value.* == .hurt)
                value.* = .idle;
        }
    }
    if (panel.active) panel.update(delta);
}

pub fn render() void {
    camera.draw(background, .init(0, 0));

    for (areas, textures, status, 0..) |area, texture, s, index| {
        if (s == .none) continue;

        const size = area.size();
        const x: f32 = @floatFromInt(@intFromEnum(s));
        const sub = gfx.Rectangle.init(.init(x * size.x, 0), size);
        camera.draw(texture.subTexture(sub), area.min);

        if (!attackTimer.isRunning() and index == selected) {
            const offset = gfx.Vector.init(90 - size.x / 2, 40);
            camera.draw(targetTexture, area.min.sub(offset));
        }
    }

    if (panel.active) panel.render();

    // for (areas) |area| camera.debugDraw(area);
}
