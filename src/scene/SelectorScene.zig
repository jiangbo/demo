const std = @import("std");
const window = @import("../window.zig");
const gfx = @import("../graphics.zig");

const changeCurrentScene = @import("../scene.zig").changeCurrentScene;

const SelectorScene = @This();
pub fn init() SelectorScene {
    std.log.info("selector scene init", .{});
    return .{};
}

pub fn enter(self: *SelectorScene) void {
    std.log.info("selector scene enter", .{});
    _ = self;
}

pub fn exit(self: *SelectorScene) void {
    std.log.info("selector scene exit", .{});
    _ = self;
}

pub fn event(self: *SelectorScene, ev: *const window.Event) void {
    std.log.info("selector scene event", .{});
    _ = self;
    _ = ev;
}

pub fn update(self: *SelectorScene) void {
    std.log.info("selector scene update", .{});
    _ = self;
}

pub fn render(self: *SelectorScene) void {
    std.log.info("selector scene render", .{});
    _ = self;
}
