const std = @import("std");

const context = @import("context.zig");

pub fn init() void {
    std.log.info("scene init current={s}", .{@tagName(context.currentScene)});
}

pub fn deinit() void {}

pub fn update(delta: f32) void {
    context.applyPendingScene();
    if (context.paused) return;
    _ = delta * context.timeScale;
}

pub fn draw() void {}
