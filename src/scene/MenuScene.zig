const std = @import("std");
const window = @import("../window.zig");
const gfx = @import("../graphics.zig");

const scene = @import("../scene.zig");
const MenuScene = @This();

background: gfx.Texture,

pub fn init() MenuScene {
    std.log.info("menu scene init", .{});

    return .{
        .background = gfx.loadTexture("assets/menu_background.png").?,
    };
}

pub fn enter(self: *MenuScene) void {
    std.log.info("menu scene enter", .{});
    _ = self;
}

pub fn exit(self: *MenuScene) void {
    std.log.info("menu scene exit", .{});
    _ = self;
}

pub fn event(self: *MenuScene, ev: *const window.Event) void {
    if (ev.type == .KEY_UP) scene.changeCurrentScene(.game);

    _ = self;
}

pub fn update(self: *MenuScene) void {
    std.log.info("menu scene update", .{});
    _ = self;
}

pub fn render(self: *MenuScene) void {
    gfx.draw(0, 0, self.background);
    window.displayText(2, 2, "menu scene");
}
