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

    var explosion = obj.Entity{};
    explosion.initTexture(app, "gfx/explosion.png");

    const seed = @as(u64, @intCast(std.time.timestamp()));
    stage = obj.Stage{
        .allocator = alloc,
        .arena = std.heap.ArenaAllocator.init(alloc),
        .rand = std.rand.DefaultPrng.init(seed),
        .player = player,
        .bullet = bullet,
        .enemy = enemy,
        .enemyBullet = enemyBullet,
        .explosion = explosion,
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
    draw.drawBackground(app, stage.backgroundX);
    draw.drawStars(app, &stage.stars);
    drawPlayer(app);
    drawEnemies(app);
    drawBullets(app);
    draw.drawExplosion(app, stage.explosionList);
}

pub fn presentScene(app: *obj.App, startTime: i64) void {
    draw.presentScene(app, startTime);
}

fn resetStage() void {
    stageResetTimer = obj.FPS * 3;
    stage.player.x = 100;
    stage.player.y = 100;
    stage.player.health = true;
    stage.arena.deinit();

    stage.arena = std.heap.ArenaAllocator.init(stage.allocator);
    stage.bulletList = obj.EntityList{};
    stage.enemyList = obj.EntityList{};
    stage.explosionList = obj.ExplosionList{};
    stage.debrisList = obj.DebrisList{};

    initStars();
    logic.initLogic();
}

fn initStars() void {
    var random = stage.rand.random();
    for (&stage.stars) |*value| {
        value.x = random.intRangeLessThan(i32, 0, obj.SCREEN_WIDTH);
        value.y = random.intRangeLessThan(i32, 0, obj.SCREEN_HEIGHT);
        value.speed = random.intRangeAtMost(i32, 1, 8);
    }
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

fn drawDebris(app: *obj.App) void {
    var it = stage.debrisList.first;
    while (it) |node| : (it = node.next) {
        draw.blitEntity(app, &node.data);
    }
}
