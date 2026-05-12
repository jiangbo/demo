const std = @import("std");

const context = @import("context.zig");
const title = @import("title.zig");

pub fn init() void {
    std.log.info("scene init current={s}", .{@tagName(context.currentScene)});
}

pub fn deinit() void {}

pub fn update(delta: f32) void {
    context.applyPendingScene();
    if (context.paused) return;

    const scaled = delta * context.timeScale;
    switch (context.currentScene) {
        .title => title.update(scaled),
        .farm => {},
    }
}

pub fn draw() void {
    switch (context.currentScene) {
        .title => title.draw(),
        .farm => {},
    }
}
