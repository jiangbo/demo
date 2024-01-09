const std = @import("std");
const obj = @import("obj.zig");
const c = @import("c.zig");
const draw = @import("draw.zig");

const EntityList = std.DoublyLinkedList(obj.Entity);
const Stage = struct {
    arena: std.heap.ArenaAllocator,
    player: obj.Entity,
    bullet: obj.Entity,
    bulletList: EntityList,
    enemy: obj.Entity,
    enemyList: EntityList,
};

const PLAYER_SPEED = 4;
const PLAYER_BULLET_SPEED = 16;

var stage: Stage = undefined;
var enemySpawnTimer: isize = 0;
var rand: std.rand.DefaultPrng = undefined;

pub fn initStage(app: *obj.App, alloc: std.mem.Allocator) !void {
    var player = obj.Entity{ .x = 100, .y = 100 };
    player.initTexture(app, "gfx/player.png");

    var bullet = obj.Entity{
        .x = 100,
        .y = 100,
        .dx = PLAYER_BULLET_SPEED,
        .health = true,
    };
    bullet.initTexture(app, "gfx/playerBullet.png");

    var enemy = obj.Entity{ .x = 100, .y = 100 };
    enemy.initTexture(app, "gfx/enemy.png");

    stage = Stage{
        .arena = std.heap.ArenaAllocator.init(alloc),
        .player = player,
        .bullet = bullet,
        .bulletList = EntityList{},
        .enemy = enemy,
        .enemyList = EntityList{},
    };

    rand = std.rand.DefaultPrng.init(undefined);
}

pub fn deinitStage() void {
    stage.player.deinit();
    stage.bullet.deinit();
    stage.enemy.deinit();
    stage.arena.deinit();
}

pub fn prepareScene(app: *obj.App) void {
    draw.prepareScene(app);
}

pub fn logicStage(app: *obj.App) void {
    doPlayer(app);
    doFighters();
    doBullets();
    spawnEnemies();
}

pub fn drawStage(app: *obj.App) void {
    drawPlayer(app);
    drawFighters(app);
    drawBullets(app);
}

pub fn presentScene(app: *obj.App, startTime: i64) void {
    draw.presentScene(app, startTime);
}

fn doPlayer(app: *obj.App) void {
    stage.player.dx = 0;
    stage.player.dy = 0;
    if (stage.player.reload > 0) {
        stage.player.reload = stage.player.reload - 1;
    }

    if (app.keyboard[c.SDL_SCANCODE_UP]) {
        stage.player.dy = -PLAYER_SPEED;
    }

    if (app.keyboard[c.SDL_SCANCODE_DOWN]) {
        stage.player.dy = PLAYER_SPEED;
    }

    if (app.keyboard[c.SDL_SCANCODE_LEFT]) {
        stage.player.dx = -PLAYER_SPEED;
    }

    if (app.keyboard[c.SDL_SCANCODE_RIGHT]) {
        stage.player.dx = PLAYER_SPEED;
    }

    if (app.keyboard[c.SDL_SCANCODE_LCTRL] and stage.player.reload == 0) {
        fireBullet();
    }

    stage.player.x += stage.player.dx;
    stage.player.y += stage.player.dy;

    if (stage.player.x < 0) stage.player.x = 0;
    if (stage.player.y < 0) stage.player.y = 0;

    const w: f32 = @floatFromInt(stage.player.w);
    if (stage.player.x + w > obj.SCREEN_WIDTH)
        stage.player.x = @floatFromInt(obj.SCREEN_WIDTH - stage.player.w);
    const h: f32 = @floatFromInt(stage.player.h);
    if (stage.player.y + h > obj.SCREEN_HEIGHT)
        stage.player.y = @floatFromInt(obj.SCREEN_HEIGHT - stage.player.h);
}

fn fireBullet() void {
    const allocator = stage.arena.allocator();
    var bullet = allocator.create(EntityList.Node) catch |err| {
        std.log.err("fire buillet error: {}\n", .{err});
        return;
    };
    bullet.data.copy(&stage.bullet);
    bullet.data.initPosition(stage.player.x, stage.player.y);
    const h = @as(f32, @floatFromInt(stage.player.h)) / 2;
    bullet.data.y += h - @as(f32, @floatFromInt(stage.bullet.h)) / 2;

    stage.bulletList.append(bullet);
    stage.player.reload = 8;
}

fn doFighters() void {
    var it = stage.enemyList.first;
    while (it) |node| : (it = node.next) {
        node.data.x += node.data.dx;
        node.data.y += node.data.dy;
        if (node.data.x < -@as(f32, @floatFromInt(node.data.w))) {
            stage.enemyList.remove(node);
            stage.arena.allocator().destroy(node);
        }
    }
}

fn doBullets() void {
    var it = stage.bulletList.first;
    while (it) |node| : (it = node.next) {
        node.data.x += node.data.dx;
        node.data.y += node.data.dy;
        if (node.data.x > obj.SCREEN_WIDTH) {
            stage.bulletList.remove(node);
            stage.arena.allocator().destroy(node);
        }
    }
}

fn spawnEnemies() void {
    enemySpawnTimer -= 1;
    if (enemySpawnTimer > 0) return;

    const allocator = stage.arena.allocator();
    var enemy = allocator.create(EntityList.Node) catch |err| {
        std.log.err("spawn enemies error: {}\n", .{err});
        return;
    };

    enemy.data.copy(&stage.enemy);

    var random = rand.random();
    const y: f32 = @floatFromInt(random.uintLessThan(u32, obj.SCREEN_HEIGHT));
    enemy.data.initPosition(obj.SCREEN_WIDTH, y);
    enemy.data.dx = -@as(f32, @floatFromInt(random.intRangeAtMost(i32, 2, 5)));
    enemySpawnTimer = random.intRangeLessThan(i32, 30, 90);

    stage.enemyList.append(enemy);
}

fn drawPlayer(app: *obj.App) void {
    draw.blitEntity(app, &stage.player);
}

fn drawFighters(app: *obj.App) void {
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
