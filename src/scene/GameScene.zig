const std = @import("std");
const window = @import("../window.zig");
const gfx = @import("../graphics.zig");

const changeCurrentScene = @import("../scene.zig").changeCurrentScene;
const GameScene = @This();
animation: gfx.BoundedFrameAnimation(9),

pub fn init() GameScene {
    std.log.info("game scene init", .{});

    var self: GameScene = .{
        .animation = .init("assets/peashooter_idle_{}.png"),
    };
    self.animation.loop = false;
    self.animation.callback = struct {
        pub fn callback() void {
            changeCurrentScene(.menu);
        }
    }.callback;

    return self;
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
        .SPACE => changeCurrentScene(.menu),
        else => {},
    };
}

pub fn update(self: *GameScene) void {
    self.animation.update(window.deltaMillisecond());
}

pub fn render(self: *GameScene) void {
    self.animation.play(300, 300);
    window.displayText(2, 2, "game scene");
}
