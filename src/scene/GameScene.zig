const std = @import("std");
const window = @import("../window.zig");
const gfx = @import("../graphics.zig");

const scene = @import("../scene.zig");
const Player = @import("player.zig").Player;
const GameScene = @This();

player1: Player = undefined,
player2: Player = undefined,

imageSky: gfx.Texture,
imageHill: gfx.Texture,

platforms: [4]Platform = undefined,

pub fn init() GameScene {
    std.log.info("game scene init", .{});

    var self: GameScene = undefined;

    self.imageSky = gfx.loadTexture("assets/sky.png").?;
    self.imageHill = gfx.loadTexture("assets/hills.png").?;

    self.initPlatforms();

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

    self.player1 = .init(scene.playerType1, 200, 50, false);
    self.player2 = .init(scene.playerType2, 975, 50, true);
}

pub fn exit(self: *GameScene) void {
    std.log.info("game scene exit", .{});
    _ = self;
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

    self.player1.draw();
    self.player2.draw();
}

const Platform = struct {
    x: f32,
    y: f32,
    texture: gfx.Texture,
    shape: Collision = .{ .left = 0, .right = 0, .y = 0 },

    const Collision = struct { left: f32, right: f32, y: f32 };
};
