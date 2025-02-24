const std = @import("std");
const gfx = @import("graphics.zig");
const cache = @import("cache.zig");
const context = @import("context.zig");
const window = @import("window.zig");
const animation = @import("animation.zig");

const math = @import("math.zig");
const Player = @import("player.zig").Player;

var background: gfx.Texture = undefined;

fn init() void {
    const allocator = context.allocator;
    cache.init(allocator);

    context.camera = gfx.Camera.init(context.width, context.height);
    context.textureSampler = gfx.Sampler.liner();

    context.batchBuffer = gfx.BatchBuffer.init(allocator) catch unreachable;

    // 加载背景
    background = cache.TextureCache.load("assets/img/background.png").?;

    // 加载角色
    player = Player.init();

    enemies = std.ArrayList(Enemy).init(allocator);
    // 加载敌人动画资源
    _ = Enemy.init();
}

const Direction = enum { left, right, up, down };

fn initEnemyPosition(enemy: *Enemy) void {
    const direction = context.rand.enumValue(Direction);
    switch (direction) {
        .left => {
            enemy.x = -enemy.currentTexture().width;
            enemy.y = context.rand.float(f32) * context.height;
        },
        .right => {
            enemy.x = context.width;
            enemy.y = context.rand.float(f32) * context.height;
        },
        .up => {
            enemy.x = context.rand.float(f32) * context.width;
            enemy.y = -enemy.currentTexture().height;
        },
        .down => {
            enemy.x = context.rand.float(f32) * context.width;
            enemy.y = context.height;
        },
    }
}

const Enemy = struct {
    x: f32 = 0,
    y: f32 = 0,
    animation: animation.FrameAnimation,
    shadow: gfx.Texture,
    faceLeft: bool = true,
    speed: f32 = 0.1,

    pub fn init() Enemy {
        const leftFmt: []const u8 = "assets/img/enemy_left_{}.png";
        const left = animation.FixedSizeFrameAnimation.load(leftFmt, 50).?;

        const rightFmt = "assets/img/enemy_right_{}.png";
        const right = animation.FixedSizeFrameAnimation.load(rightFmt, 50).?;

        return Enemy{
            .animation = .{ .left = left, .right = right },
            .shadow = cache.TextureCache.load("assets/img/shadow_enemy.png").?,
        };
    }

    pub fn update(self: *Enemy, delta: f32) void {
        const playerPos = math.Vector2{ .x = player.x, .y = player.y };
        const enemyPos = math.Vector2{ .x = self.x, .y = self.y };
        const normalized = playerPos.sub(enemyPos).normalize();

        self.x += normalized.x * delta * self.speed;
        self.y += normalized.y * delta * self.speed;

        self.faceLeft = normalized.x < 0;

        if (self.faceLeft)
            self.animation.left.play(delta)
        else
            self.animation.right.play(delta);
    }

    pub fn currentTexture(self: Enemy) gfx.Texture {
        return if (self.faceLeft)
            self.animation.left.currentTexture()
        else
            self.animation.right.currentTexture();
    }

    pub fn shadowX(self: Enemy) f32 {
        const width = self.currentTexture().width - self.shadow.width;
        return self.x + width / 2;
    }

    pub fn shadowY(self: Enemy) f32 {
        return self.y + self.currentTexture().height - 25;
    }
};

var player: Player = undefined;
var enemies: std.ArrayList(Enemy) = undefined;

const enemyGenerateInterval: f32 = 2000;

var enemyGenerateTimer: f32 = 0;
fn tryGenerateEnemy() void {
    enemyGenerateTimer += window.deltaMillisecond();
    if (enemyGenerateTimer >= enemyGenerateInterval) {
        enemyGenerateTimer = 0;
        enemies.append(Enemy.init()) catch unreachable;
        initEnemyPosition(&enemies.items[enemies.items.len - 1]);
    }
}

fn frame() void {
    const delta = window.deltaMillisecond();
    player.update(delta);
    tryGenerateEnemy();
    for (enemies.items) |*enemy| {
        enemy.update(delta);
    }

    // 碰撞检测
    checkBulletEnemyCollision();
    checkPlayerEnemyCollision();

    var renderPass = gfx.CommandEncoder.beginRenderPass(context.clearColor);
    defer renderPass.submit();

    var single = gfx.TextureSingle.begin(renderPass);

    single.draw(0, 0, background);

    // 敌人
    for (enemies.items) |enemy| {
        single.draw(enemy.shadowX(), enemy.shadowY(), enemy.shadow);
        single.draw(enemy.x, enemy.y, enemy.currentTexture());
    }

    // 玩家
    single.draw(player.shadowX(), player.shadowY(), player.shadow);
    single.draw(player.x, player.y, player.currentTexture());

    // 子弹
    for (&player.bullets) |bullet| {
        single.draw(bullet.x, bullet.y, bullet.texture);
    }
}

fn checkBulletEnemyCollision() void {
    for (&player.bullets) |bullet| {
        const bulletCenterX = bullet.x + bullet.texture.width / 2;
        const bulletCenterY = bullet.y + bullet.texture.height / 2;
        for (enemies.items, 0..) |enemy, index| {
            const enemyRectangle = math.Rectangle{
                .x = enemy.x,
                .y = enemy.y,
                .width = enemy.currentTexture().width,
                .height = enemy.currentTexture().height,
            };
            if (enemyRectangle.contains(bulletCenterX, bulletCenterY)) {
                _ = enemies.swapRemove(index);
            }
        }
    }
}

fn checkPlayerEnemyCollision() void {
    for (enemies.items) |enemy| {
        const playerRect = math.Rectangle{
            .x = player.x,
            .y = player.y,
            .width = player.currentTexture().width,
            .height = player.currentTexture().height,
        };

        const enemyCenterX = enemy.x + enemy.currentTexture().width / 2;
        const enemyCenterY = enemy.y + enemy.currentTexture().height / 2;

        if (playerRect.contains(enemyCenterX, enemyCenterY)) {
            std.log.info("collision", .{});
            window.exit();
        }
    }
}

fn event(evt: ?*const window.Event) void {
    if (evt) |e| player.processEvent(e);
}

fn deinit() void {
    enemies.deinit();
    context.batchBuffer.deinit(context.allocator);
    cache.deinit();
}

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    context.allocator = gpa.allocator();

    context.width = 1280;
    context.height = 720;

    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    context.rand = prng.random();
    window.run(.{ .init = init, .event = event, .frame = frame, .deinit = deinit });
}
