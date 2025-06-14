const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const camera = @import("camera.zig");

const titleScene = @import("scene/title.zig");
const worldScene = @import("scene/world.zig");

const Talk = struct { content: []const u8 };
pub const talks: []const Talk = @import("talk.zon");

const SceneType = enum { title, world };
var currentSceneType: SceneType = .title;

var vertexBuffer: [100 * 4]camera.Vertex = undefined;

pub fn init() void {
    camera.init(.init(.zero, window.size), .init(1000, 800), &vertexBuffer);

    titleScene.init();
    worldScene.init();
    window.fontTexture = gfx.loadTexture("assets/4_0.png", .init(512, 512));

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
    var buffer: [20]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "FPS: {}", .{window.frameRate});
    camera.drawTextOptions(.{
        .text = text catch unreachable,
        .position = .init(20, 20),
        .color = .{ .r = 0, .g = 1, .b = 0, .a = 1 },
    });
}

fn sceneCall(comptime function: []const u8, args: anytype) void {
    switch (currentSceneType) {
        .title => window.call(titleScene, function, args),
        .world => window.call(worldScene, function, args),
    }
}
