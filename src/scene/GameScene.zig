const std = @import("std");
const window = @import("../window.zig");
const gfx = @import("../graphics.zig");

const scene = @import("../scene.zig");
const GameScene = @This();

pub const ShakeCamera = struct {
    x: f32 = 0,
    y: f32 = 0,
    isShaking: bool = false,
    duration: f32,
    timer: f32 = 0,
    magnitude: f32,

    pub fn update(self: *ShakeCamera, deltaTime: f32) void {
        if (!self.isShaking) return;

        self.timer += deltaTime;
        if (self.timer >= self.duration) {
            self.timer = 0;
            self.isShaking = false;
        } else {
            const randomX = std.crypto.random.float(f32) * 2 - 1;
            self.x = scene.camera.x + randomX * self.magnitude;
            const randomY = std.crypto.random.float(f32) * 2 - 1;
            self.y = scene.camera.y + randomY * self.magnitude;
        }
    }

    pub fn restart(self: *ShakeCamera) void {
        self.timer = 0;
        self.isShaking = true;
    }
};

const Player = union(scene.PlayerType) {
    peaShooter: PeaShooterPlayer,
    sunFlower: SunFlowerPlayer,

    pub fn update(self: *Player) void {
        switch (self.*) {
            inline else => |*s| s.update(),
        }
    }
};

animation: gfx.BoundedFrameAnimation(9),
shakeCamera: ShakeCamera,

player1: Player = undefined,
player2: Player = undefined,

imageSky: gfx.Texture,
imageHill: gfx.Texture,

platforms: [4]Platform = undefined,

pub fn init() GameScene {
    std.log.info("game scene init", .{});

    var self: GameScene = undefined;

    self.shakeCamera = .{ .duration = 350, .magnitude = 10 };
    self.animation = .init("assets/peashooter_idle_{}.png");
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

    self.player1 = if (scene.playerType1 == .peaShooter)
        .{ .peaShooter = .init(100, 400) }
    else
        .{ .sunFlower = .init(100, 400) };

    self.player2 = if (scene.playerType2 == .peaShooter)
        .{ .peaShooter = .init(800, 400) }
    else
        .{ .sunFlower = .init(800, 400) };
}

pub fn exit(self: *GameScene) void {
    std.log.info("game scene exit", .{});
    _ = self;
}

pub fn event(self: *GameScene, ev: *const window.Event) void {
    if (ev.type == .KEY_UP) switch (ev.key_code) {
        .Q => scene.changeCurrentScene(.menu),
        .SPACE => self.shakeCamera.restart(),
        else => {},
    };
}

pub fn update(self: *GameScene) void {
    const deltaTime = window.deltaMillisecond();
    self.animation.update(deltaTime);
    self.shakeCamera.update(deltaTime);

    self.player1.update();
    self.player2.update();
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
}

const Platform = struct {
    x: f32,
    y: f32,
    texture: gfx.Texture,
    shape: Collision = .{ .left = 0, .right = 0, .y = 0 },

    const Collision = struct { left: f32, right: f32, y: f32 };
};

const PeaShooterPlayer = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) PeaShooterPlayer {
        return .{ .x = x, .y = y };
    }

    pub fn update(self: *PeaShooterPlayer) void {
        std.log.info("pea x: {}, y: {}", .{ self.x, self.y });
    }
};

const SunFlowerPlayer = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) SunFlowerPlayer {
        return .{ .x = x, .y = y };
    }

    pub fn update(self: *SunFlowerPlayer) void {
        std.log.info("sun x: {}, y: {}", .{ self.x, self.y });
    }
};
