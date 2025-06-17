const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const camera = @import("camera.zig");

const titleScene = @import("scene/title.zig");
const worldScene = @import("scene/world.zig");

const Talk = struct { content: []const u8 };
pub const talks: []const Talk = @import("zon/talk.zon");

const SceneType = enum { title, world };
var currentSceneType: SceneType = .title;
var toSceneType: SceneType = .title;

var vertexBuffer: [100 * 4]camera.Vertex = undefined;
var fontVertexBuffer: [1000 * 4]window.FontVertex = undefined;

pub fn init() void {
    const fontTexture = gfx.loadTexture("assets/font.png", .init(504, 504));
    window.initFont(.{
        .font = &@import("zon/font.zon"),
        .texture = fontTexture,
        .size = window.size,
        .vertex = &fontVertexBuffer,
    });

    camera.init(&vertexBuffer);

    titleScene.init();
    worldScene.init();

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
    toSceneType = sceneType;
    fadeOut(doChangeScene);
}

fn doChangeScene() void {
    exit();
    currentSceneType = toSceneType;
    enter();
}

pub fn update(delta: f32) void {
    if (fadeTimer) |*timer| {
        if (timer.isRunningAfterUpdate(delta)) return;
        if (isFadeIn) {
            fadeTimer = null;
        } else {
            if (fadeOutCallback) |callback| callback();
            isFadeIn = true;
            timer.restart();
        }
        return;
    }
    sceneCall("update", .{delta});
}

pub fn render() void {
    camera.beginDraw(.{ .a = 1 });
    defer camera.endDraw();

    window.keepAspectRatio();

    sceneCall("render", .{});

    if (fadeTimer) |*timer| {
        const percent = timer.elapsed / timer.duration;
        const a = if (isFadeIn) 1 - percent else percent;
        camera.drawRectangle(.init(.zero, window.size), .{ .a = a });
    }

    var buffer: [20]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "FPS:{}", .{window.frameRate});
    camera.drawTextOptions(.{
        .text = text catch unreachable,
        .position = .init(10, 5),
        .color = .{ .r = 0, .g = 1, .b = 0, .a = 1 },
    });
}

var fadeTimer: ?window.Timer = null;
var isFadeIn: bool = false;
var fadeOutCallback: ?*const fn () void = null;

pub fn fadeIn() void {
    isFadeIn = true;
    fadeTimer = .init(2);
}

pub fn fadeOut(callback: ?*const fn () void) void {
    isFadeIn = false;
    fadeTimer = .init(2);
    fadeOutCallback = callback;
}

fn sceneCall(comptime function: []const u8, args: anytype) void {
    switch (currentSceneType) {
        .title => window.call(titleScene, function, args),
        .world => window.call(worldScene, function, args),
    }
}
