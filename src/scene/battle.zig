const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const world = @import("world.zig");
const camera = @import("../camera.zig");
const panel = @import("panel.zig");
const math = @import("../math.zig");

pub const Enemy = struct {
    active: bool = true,
    health: u32 = 100,
    maxHealth: u32 = 100,
    attack: u32 = 10,
    defend: u32 = 10,
    speed: f32 = 10,
    luck: u32 = 10,
};

const statusEnum = enum { idle, attack, hurt, dead, none };

var background: gfx.Texture = undefined;
var enemyTexture: gfx.Texture = undefined;
var enemies: [3]Enemy = undefined;
var targetTexture: gfx.Texture = undefined;

var attackTimer: window.Timer = .init(0.4);
pub var selected: usize = 0;
pub var phase: enum { normal, prepare, select, battle } = .normal;

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
var actions: [areas.len]u8 = [1]u8{0} ** areas.len;
var timers: [areas.len]window.Timer = undefined;
var timerIndex: usize = 0;

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

const SPEED_TIME = 50;
pub fn enter() void {
    window.playMusic("assets/fight/fight.ogg");
    for (&world.players, 0..) |player, index| {
        const speed: f32 = @floatFromInt(player.speed);
        timers[index] = .init(SPEED_TIME / speed);
    }

    const enemyArray: [3]Enemy = .{ .{}, .{ .active = false }, .{ .speed = 20 } };

    @memset(status[3..], .none);
    for (enemyArray, 0..) |enemy, index| {
        enemies[index] = enemy;
        timers[3 + index] = .init(SPEED_TIME / enemy.speed);
        if (enemy.active) status[3 + index] = .idle;
    }
}

pub fn exit() void {
    window.stopMusic();
}

pub fn selectFirstEnemy() void {
    for (status[3..], 3..) |s, index| {
        if (s == .idle) selected = index;
        break;
    }
}

pub fn selectPrevEnemy() void {
    selected -= 1;
    while (selected > 2) : (selected -= 1) {
        if (status[selected] == .idle) break;
    } else {
        selected = 6;
        selectPrevEnemy();
    }
}

pub fn selectNextEnemy() void {
    selected += 1;
    while (selected < 6) : (selected += 1) {
        if (status[selected] == .idle) break;
    } else {
        selected = 2;
        selectNextEnemy();
    }
}

pub fn startAttackSelected(attack: usize, use: u8) void {
    startAttack(attack, selected, use);
}

fn startAttack(attack: usize, hurt: usize, use: u8) void {
    attackTimer.reset();
    status[attack] = .attack;
    timers[attack].reset();
    actions[attack] = use;
    status[hurt] = .hurt;
    phase = .battle;
}

pub fn update(delta: f32) void {
    if (phase == .prepare or phase == .select) {
        panel.update(delta);
        return;
    }

    if (attackTimer.isFinishedAfterUpdate(delta)) {
        for (&status) |*value| {
            if (value.* == .attack or value.* == .hurt)
                value.* = .idle;
        }
        if (phase == .battle) phase = .normal;
    }

    if (phase == .battle) return;

    const i = if (timerIndex == 6) 0 else timerIndex;
    for (timers[i..], status[i..], i..) |*timer, s, index| {
        if (s != .idle) continue;

        timerIndex = index + 1;
        if (timer.isRunningAfterUpdate(delta)) continue;

        if (index == 3 or index == 4 or index == 5) {
            break startAttack(index, math.randU8(0, 2), 0);
        }

        if (index == 0 or index == 1 or index == 2) {
            break panel.onPlayerTurn(index);
        }
    }
}

pub fn render() void {
    camera.draw(background, .init(0, 0));

    for (areas, textures, status) |area, texture, s| {
        if (s == .none) continue;

        const size = area.size();
        const x: f32 = @floatFromInt(@intFromEnum(s));
        const sub = gfx.Rectangle.init(.init(x * size.x, 0), size);
        camera.draw(texture.subTexture(sub), area.min);
    }

    if (phase == .battle or phase == .normal) return;

    renderTarget();
    panel.render();

    // for (areas) |area| camera.debugDraw(area);
    // camera.debugDraw(areas[3]);
}

fn renderTarget() void {
    for (areas, 0..) |area, index| {
        if (attackTimer.isRunning() or index != selected) continue;
        camera.draw(targetTexture, area.min.add(.init(40, -40)));
    }
}
