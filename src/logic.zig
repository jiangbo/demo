const std = @import("std");
const obj = @import("obj.zig");
const c = @import("c.zig");
const utils = @import("utils.zig");

const PLAYER_SPEED = 4;
const ENEMY_BULLET_SPEED = 8;
var enemySpawnTimer: isize = 0;

pub fn initLogic() void {
    enemySpawnTimer = 0;
    _ = c.SDL_ShowCursor(0);
}

pub fn logicStage(app: *obj.App, stage: *obj.Stage) void {
    doBackground(stage);
    doStars(stage);
    doPlayer(app, stage);
    doEnemies(stage);
    doBullets(stage);
    spawnEnemies(stage);
    doExplosions(stage);
    doDebris(stage);
}

fn doBackground(stage: *obj.Stage) void {
    stage.backgroundX -= 1;
    if (stage.backgroundX < -obj.SCREEN_WIDTH) {
        stage.backgroundX = 0;
    }
}

fn doStars(stage: *obj.Stage) void {
    for (&stage.stars) |*value| {
        value.x -= value.speed;
        if (value.x < 0) value.x = obj.SCREEN_WIDTH + value.x;
    }
}

fn doPlayer(app: *obj.App, stage: *obj.Stage) void {
    if (!stage.player.health) return;

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
        fireBullet(stage);
    }

    stage.player.x += stage.player.dx;
    stage.player.y += stage.player.dy;

    if (stage.player.x < 0) stage.player.x = 0;
    if (stage.player.y < 0) stage.player.y = 0;

    if (stage.player.x + stage.player.w > obj.SCREEN_WIDTH / 2)
        stage.player.x = obj.SCREEN_WIDTH / 2 - stage.player.w;
    if (stage.player.y + stage.player.h > obj.SCREEN_HEIGHT)
        stage.player.y = obj.SCREEN_HEIGHT - stage.player.h;
}

fn fireBullet(stage: *obj.Stage) void {
    const allocator = stage.arena.allocator();
    var bullet = allocator.create(obj.EntityList.Node) catch |err| {
        std.log.err("fire buillet error: {}\n", .{err});
        return;
    };
    bullet.data.copy(&stage.bullet);
    bullet.data.initPosition(stage.player.x, stage.player.y);
    bullet.data.y += (stage.player.h - stage.bullet.h) / 2;

    stage.bulletList.append(bullet);
    stage.player.reload = 8;
}

fn doEnemies(stage: *obj.Stage) void {
    var it = stage.enemyList.first;
    while (it) |node| : (it = node.next) {
        node.data.x += node.data.dx;
        node.data.y += node.data.dy;
        if (node.data.x < -node.data.w or !node.data.health) {
            stage.enemyList.remove(node);
            stage.arena.allocator().destroy(node);
        }
        node.data.reload -= 1;
        if (node.data.reload <= 0) fireEnemyBullet(stage, &node.data);
    }
}

fn fireEnemyBullet(stage: *obj.Stage, enemy: *obj.Entity) void {
    const allocator = stage.arena.allocator();
    var bullet = allocator.create(obj.EntityList.Node) catch |err| {
        std.log.err("fire enemy buillet error: {}\n", .{err});
        return;
    };
    bullet.data.copy(&stage.enemyBullet);
    bullet.data.initPosition(enemy.x, enemy.y);
    bullet.data.x += enemy.w / 2 - bullet.data.w / 2;
    bullet.data.y += enemy.h / 2 - bullet.data.h / 2;

    utils.calcSlope(&stage.player, enemy, &bullet.data);

    bullet.data.dx *= ENEMY_BULLET_SPEED;
    bullet.data.dy *= ENEMY_BULLET_SPEED;
    enemy.reload = @mod(stage.rand.random().int(i32), obj.FPS * 4);
    stage.bulletList.append(bullet);
}

fn doBullets(stage: *obj.Stage) void {
    var it = stage.bulletList.first;
    while (it) |node| : (it = node.next) {
        node.data.x += node.data.dx;
        node.data.y += node.data.dy;
        if (bulletHitFighter(&node.data, stage) or !node.data.health //
        or node.data.x < 0 or node.data.x > obj.SCREEN_WIDTH //
        or node.data.y < 0 or node.data.y > obj.SCREEN_HEIGHT) {
            stage.bulletList.remove(node);
            stage.arena.allocator().destroy(node);
        }
    }
}

fn bulletHitFighter(bullet: *obj.Entity, stage: *obj.Stage) bool {
    if (!stage.player.health and bullet.enemy) return false;

    if (bullet.enemy and utils.collision(bullet, &stage.player)) {
        stage.player.health = false;
        addExplosions(stage, stage.player.x, stage.player.y, 32);
        // addDebris(e);
        return true;
    }

    var it = stage.enemyList.first;
    while (it) |node| : (it = node.next) {
        if (node.data.enemy == bullet.enemy) continue;
        if (utils.collision(bullet, &node.data)) {
            addExplosions(stage, node.data.x, node.data.y, 32);
            bullet.health = false;
            node.data.health = false;
        }
    }
    return false;
}

fn spawnEnemies(stage: *obj.Stage) void {
    enemySpawnTimer -= 1;
    if (enemySpawnTimer > 0) return;

    const allocator = stage.arena.allocator();
    var enemy = allocator.create(obj.EntityList.Node) catch |err| {
        std.log.err("spawn enemies error: {}\n", .{err});
        return;
    };

    enemy.data.copy(&stage.enemy);

    var random = stage.rand.random();
    const y: f32 = obj.SCREEN_HEIGHT - enemy.data.h;
    enemy.data.initPosition(obj.SCREEN_WIDTH, random.float(f32) * y);
    enemy.data.dx = -@as(f32, @floatFromInt(random.intRangeAtMost(i32, 2, 5)));
    enemy.data.reload = random.intRangeAtMost(i32, 1, 3);
    enemySpawnTimer = random.intRangeLessThan(i32, 30, 90);

    stage.enemyList.append(enemy);
}

fn doExplosions(stage: *obj.Stage) void {
    var it = stage.explosionList.first;
    while (it) |node| : (it = node.next) {
        node.data.x += node.data.dx;
        node.data.y += node.data.dy;

        node.data.a -%= 1;
        if (node.data.a <= 0) {
            stage.explosionList.remove(node);
            stage.arena.allocator().destroy(node);
        }
    }
}

fn doDebris(stage: *obj.Stage) void {
    var it = stage.debrisList.first;
    while (it) |node| : (it = node.next) {
        node.data.x += node.data.dx;
        node.data.y += node.data.dy;
        node.data.dy += 0.5;

        node.data.life -= 1;
        if (node.data.life <= 0) {
            stage.debrisList.remove(node);
            stage.arena.allocator().destroy(node);
        }
    }
}

fn addExplosions(stage: *obj.Stage, x: f32, y: f32, num: usize) void {
    const allocator = stage.arena.allocator();
    var random = stage.rand.random();
    for (0..num) |_| {
        var explosion = allocator.create(obj.ExplosionList.Node) catch |err| {
            std.log.err("add explosions error: {}\n", .{err});
            continue;
        };

        const rx = random.intRangeAtMost(i8, -31, 31);
        explosion.data.x = x + @as(f32, @floatFromInt(rx));
        const ry = random.intRangeAtMost(i8, -31, 31);
        explosion.data.y = y + @as(f32, @floatFromInt(ry));

        const dx = random.intRangeAtMost(i8, -9, 9);
        explosion.data.dx = @as(f32, @floatFromInt(dx)) / 10;
        const dy = random.intRangeAtMost(i8, -9, 9);
        explosion.data.dy = @as(f32, @floatFromInt(dy)) / 10;

        const color = random.intRangeAtMost(i8, 0, 3);
        switch (color) {
            0 => explosion.data.r = 255,
            1 => {
                explosion.data.r = 255;
                explosion.data.g = 128;
            },
            2 => {
                explosion.data.r = 255;
                explosion.data.g = 255;
            },
            else => {
                explosion.data.r = 255;
                explosion.data.g = 255;
                explosion.data.b = 255;
            },
        }

        explosion.data.a = random.intRangeLessThan(u8, 0, obj.FPS * 3);
        stage.explosionList.append(explosion);
    }
}
