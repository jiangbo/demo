const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");

const titleScene = @import("scene/title.zig");
const worldScene = @import("scene/world.zig");

const SceneType = enum { title, world };
var currentSceneType: SceneType = .world;

const SIZE: gfx.Vector = .init(1000, 800);
pub var camera: gfx.Camera = undefined;
pub var cursor: gfx.Texture = undefined;
var cursorTexture: gfx.Texture = undefined;

pub fn init() void {
    camera = .init(.init(.zero, window.size), SIZE);
    titleScene.init();
    worldScene.init(&camera);
    window.showCursor(false);
    cursorTexture = gfx.loadTexture("assets/mc_1.png", .init(32, 32));
    cursor = cursorTexture;
    enter();
}

pub fn enter() void {
    sceneCall("enter", .{});
}

pub fn exit() void {
    sceneCall("exit", .{});
}

pub fn changeScene() void {
    exit();
    const next: usize = @intFromEnum(currentSceneType);
    const len = std.enums.values(SceneType).len;
    currentSceneType = @enumFromInt((next + 1) % len);
    enter();
}

pub fn update(delta: f32) void {
    cursor = cursorTexture;
    sceneCall("update", .{delta});
}

pub fn render() void {
    camera.beginDraw(.{ .a = 1 });
    defer camera.endDraw();
    sceneCall("render", .{&camera});

    camera.draw(cursor, window.mousePosition.add(camera.rect.min));
}

fn sceneCall(comptime function: []const u8, args: anytype) void {
    switch (currentSceneType) {
        .title => @call(.auto, @field(titleScene, function), args),
        .world => @call(.auto, @field(worldScene, function), args),
    }
}
