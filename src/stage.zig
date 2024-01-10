const std = @import("std");
const obj = @import("obj.zig");
const draw = @import("draw.zig");
const input = @import("input.zig");
const logic = @import("logic.zig");

const PLAYER_BULLET_SPEED = 16;

var stage: obj.Stage = undefined;
var stageResetTimer: isize = 0;

pub fn initStage(app: *obj.App, alloc: std.mem.Allocator) void {
    var player = obj.Entity{ .enemy = false };
    player.initTexture(app, "gfx/player.png");

    var bullet = obj.Entity{ .dx = PLAYER_BULLET_SPEED, .enemy = false };
    bullet.initTexture(app, "gfx/playerBullet.png");

    var enemy = obj.Entity{};
    enemy.initTexture(app, "gfx/enemy.png");

    var enemyBullet = obj.Entity{};
    enemyBullet.initTexture(app, "gfx/alienBullet.png");

    stage = obj.Stage{
        .arena = std.heap.ArenaAllocator.init(alloc),
        .player = player,
        .bullet = bullet,
        .enemy = enemy,
        .enemyBullet = enemyBullet,
    };

    resetStage();
}

pub fn deinitStage() void {
    stage.player.deinit();
    stage.bullet.deinit();
    stage.enemy.deinit();
    stage.enemyBullet.deinit();
    stage.arena.deinit();
}

pub fn prepareScene(app: *obj.App) void {
    draw.prepareScene(app);
}

pub fn handleInput(app: *obj.App) bool {
    return input.handleInput(app);
}

pub fn logicStage(app: *obj.App) void {
    if (!stage.player.health) {
        stageResetTimer -= 1;
        if (stageResetTimer <= 0) resetStage();
    }

    logic.logicStage(app, &stage);
}

pub fn drawStage(app: *obj.App) void {
    drawPlayer(app);
    drawEnemies(app);
    drawBullets(app);
}

pub fn presentScene(app: *obj.App, startTime: i64) void {
    draw.presentScene(app, startTime);
}

fn resetStage() void {
    stageResetTimer = obj.FPS * 2;
    stage.player.x = 100;
    stage.player.y = 100;
    stage.arena.deinit();
    stage.bulletList = obj.EntityList{};
    stage.enemyList = obj.EntityList{};
    logic.initLogic();
}

fn drawPlayer(app: *obj.App) void {
    if (stage.player.health) {
        draw.blitEntity(app, &stage.player);
    }
}

fn drawEnemies(app: *obj.App) void {
    var it = stage.enemyList.first;
    while (it) |node| : (it = node.next) {
        draw.blitEntity(app, &node.data);
    }
}

fn drawBullets(app: *obj.App) void {
    var it = stage.bulletList.first;
    while (it) |node| : (it = node.next) {
        draw.blitEntity(app, &node.data);
    }
}
