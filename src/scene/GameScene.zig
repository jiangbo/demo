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

animation: gfx.BoundedFrameAnimation(9),
shakeCamera: ShakeCamera,

pub fn init() GameScene {
    std.log.info("game scene init", .{});

    return .{
        .shakeCamera = ShakeCamera{ .duration = 350, .magnitude = 10 },
        .animation = .init("assets/peashooter_idle_{}.png"),
    };
}

pub fn enter(self: *GameScene) void {
    std.log.info("game scene enter", .{});
    self.animation.index = 0;
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
}

pub fn render(self: *GameScene) void {
    self.animation.play(300 - self.shakeCamera.x, 300 - self.shakeCamera.y);
    window.displayText(2, 2, "game scene");
}
