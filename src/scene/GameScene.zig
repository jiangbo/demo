const std = @import("std");
const window = @import("../window.zig");
const gfx = @import("../graphics.zig");

const scene = @import("../scene.zig");
const GameScene = @This();
animation: gfx.BoundedFrameAnimation(9),

pub fn init() GameScene {
    std.log.info("game scene init", .{});

    return .{
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
        .A => self.animation.flip = true,
        .D => self.animation.flip = false,
        .SPACE => scene.changeCurrentScene(.menu),
        else => {},
    };
}

pub fn update(self: *GameScene) void {
    self.animation.update(window.deltaMillisecond());
}

pub fn render(self: *GameScene) void {
    scene.camera.x -= window.deltaMillisecond() * 0.1;
    self.animation.play(300 - scene.camera.x, 300 - scene.camera.y);
    window.displayText(2, 2, "game scene");
}
