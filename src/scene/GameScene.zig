const std = @import("std");
const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const audio = @import("zaudio");

const scene = @import("../scene.zig");
const Bullet = @import("bullet.zig").Bullet;
const player = @import("player.zig");
const GameScene = @This();

player1: player.Player,
player2: player.Player,

bullets: std.BoundedArray(Bullet, 64),

imageSky: gfx.Texture,
imageHill: gfx.Texture,

platforms: [4]Platform,

backgroundSound: *audio.Sound,

pub fn init() GameScene {
    std.log.info("game scene init", .{});

    window.shakeCamera = window.ShakeCamera.init(0, 0);
    var self: GameScene = undefined;

    self.imageSky = gfx.loadTexture("assets/sky.png").?;
    self.imageHill = gfx.loadTexture("assets/hills.png").?;
    self.bullets = std.BoundedArray(Bullet, 64).init(0) catch unreachable;
    self.backgroundSound = scene.audioEngine.createSoundFromFile(
        "assets/bgm_game.mp3",
        .{ .flags = .{ .stream = true, .looping = true } },
    ) catch unreachable;

    self.initPlatforms();
    @import("bullet.zig").init();

    return self;
}

fn initPlatforms(self: *GameScene) void {
    var texture = gfx.loadTexture("assets/platform_large.png").?;
    var platform: Platform = .{ .x = 122, .y = 455, .texture = texture };
    platform.shape.left = platform.x + 30;
    platform.shape.right = platform.x + texture.width - 30;
    platform.shape.y = platform.y + 60;
    self.platforms[0] = platform;

    texture = gfx.loadTexture("assets/platform_small.png").?;
    platform = .{ .x = 175, .y = 360, .texture = texture };
    platform.shape.left = platform.x + 40;
    platform.shape.right = platform.x + texture.width - 40;
    platform.shape.y = platform.y + texture.height / 2;
    self.platforms[1] = platform;

    platform = .{ .x = 855, .y = 360, .texture = texture };
    platform.shape.left = platform.x + 40;
    platform.shape.right = platform.x + texture.width - 40;
    platform.shape.y = platform.y + texture.height / 2;
    self.platforms[2] = platform;

    platform = .{ .x = 515, .y = 225, .texture = texture };
    platform.shape.left = platform.x + 40;
    platform.shape.right = platform.x + texture.width - 40;
    platform.shape.y = platform.y + texture.height / 2;
    self.platforms[3] = platform;
}

pub fn enter(self: *GameScene) void {
    std.log.info("game scene enter", .{});
    self.backgroundSound.start() catch unreachable;

    self.player1 = .init(scene.playerType1, 200, 50, false);
    self.player2 = .init(scene.playerType2, 975, 50, true);
    self.player2.p1 = false;
}

pub fn exit(self: *GameScene) void {
    std.log.info("game scene exit", .{});
    self.backgroundSound.stop() catch unreachable;
}

pub fn event(self: *GameScene, ev: *const window.Event) void {
    switch (ev.key_code) {
        .A, .D, .W, .F, .G => self.player1.event(ev),
        .LEFT, .RIGHT, .UP, .PERIOD, .SLASH => self.player2.event(ev),
        else => {},
    }
}

pub fn update(self: *GameScene) void {
    const deltaTime = window.deltaMillisecond();

    self.player1.update(deltaTime);
    self.player2.update(deltaTime);

    self.updateBullets(deltaTime);
    window.shakeCamera.update(deltaTime);
}

fn updateBullets(self: *GameScene, delta: f32) void {
    for (self.bullets.slice(), 0..) |*bullet, index| {
        bullet.update(delta);

        if (bullet.p1 and !bullet.collide and !self.player2.invulnerable) {
            if (self.player2.isCollide(bullet)) {
                bullet.collidePlayer();
                self.player2.collideBullet(bullet);
            }
        }

        if (!bullet.p1 and !bullet.collide and !self.player1.invulnerable) {
            if (self.player1.isCollide(bullet)) {
                bullet.collidePlayer();
                self.player1.collideBullet(bullet);
            }
        }
        if (bullet.dead) _ = self.bullets.swapRemove(index);
    }
}

pub fn render(self: *GameScene) void {
    var x = window.width - self.imageSky.width;
    var y = window.height - self.imageSky.height;
    gfx.draw(x / 2, y / 2, self.imageSky);

    x = window.width - self.imageHill.width;
    y = window.height - self.imageHill.height;
    gfx.draw(x / 2, y / 2, self.imageHill);

    for (&self.platforms) |platform| {
        gfx.draw(platform.x, platform.y, platform.texture);
    }

    self.player1.render();
    self.player2.render();

    for (self.bullets.slice()) |*bullet| bullet.render();
}

pub fn deinit(self: *GameScene) void {
    std.log.info("game scene deinit", .{});
    @import("bullet.zig").deinit();
    self.backgroundSound.destroy();
}

const Platform = struct {
    x: f32,
    y: f32,
    texture: gfx.Texture,
    shape: Collision = .{ .left = 0, .right = 0, .y = 0 },

    const Collision = struct { left: f32, right: f32, y: f32 };
};
