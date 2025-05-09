const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");

const titleScene = @import("scene/title.zig");
const worldScene = @import("scene/world.zig");

const SceneType = enum { title, world };

var currentSceneType: SceneType = .title;

pub fn init() void {
    titleScene.init();
    worldScene.init();
    enter();
}

pub fn enter() void {
    sceneCall("enter", .{});
}

pub fn exit() void {
    sceneCall("exit", .{});
}

pub fn update(delta: f32) void {
    if (window.isKeyPress(.SPACE)) {
        exit();
        const next: usize = @intFromEnum(currentSceneType);
        const len = std.enums.values(SceneType).len;
        currentSceneType = @enumFromInt((next + 1) % len);
        enter();
    }
    sceneCall("update", .{delta});
}

pub fn render() void {
    sceneCall("render", .{});
}

fn sceneCall(comptime function: []const u8, args: anytype) void {
    switch (currentSceneType) {
        .title => @call(.auto, @field(titleScene, function), args),
        .world => @call(.auto, @field(worldScene, function), args),
    }
}
