const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const camera = @import("camera.zig");

const titleScene = @import("scene/title.zig");
const worldScene = @import("scene/world.zig");
const battleScene = @import("scene/battle.zig");

const SceneType = enum { title, world, battle };
var currentSceneType: SceneType = .title;

const SIZE: gfx.Vector = .init(1000, 800);

var vertexBuffer: [100 * 4]camera.Vertex = undefined;

var texture: gfx.Texture = undefined;

pub fn init() void {
    camera.init(.init(.zero, window.size), SIZE, &vertexBuffer);

    titleScene.init();
    worldScene.init();
    battleScene.init();
    texture = gfx.loadTexture("assets/fight/p1.png", .init(960, 240));
    window.fontTexture = gfx.loadTexture("assets/4_0.png", .init(256, 256));

    enter();
}

pub fn event(ev: *const window.Event) void {
    titleScene.event(ev);
}

pub fn enter() void {
    sceneCall("enter", .{});
}

pub fn exit() void {
    sceneCall("exit", .{});
}

pub fn changeNextScene() void {
    const next: usize = @intFromEnum(currentSceneType);
    const len = std.enums.values(SceneType).len;
    changeScene(@enumFromInt((next + 1) % len));
}

pub fn changeScene(sceneType: SceneType) void {
    exit();
    currentSceneType = sceneType;
    enter();
}

pub fn update(delta: f32) void {
    sceneCall("update", .{delta});
}

pub fn render() void {
    camera.beginDraw(.{ .a = 1 });
    defer camera.endDraw();

    sceneCall("render", .{});
}

fn sceneCall(comptime function: []const u8, args: anytype) void {
    switch (currentSceneType) {
        .title => window.call(titleScene, function, args),
        .world => window.call(worldScene, function, args),
        .battle => window.call(battleScene, function, args),
    }
}
