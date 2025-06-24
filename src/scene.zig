const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;

const titleScene = @import("title.zig");
const worldScene = @import("world.zig");

const SceneType = enum { title, world };
var currentSceneType: SceneType = .world;
var toSceneType: SceneType = .title;

pub fn init() void {
    window.initFont(.{
        .font = @import("zon/font.zon"),
        .texture = gfx.loadTexture("assets/font.png", .init(944, 944)),
    });

    camera.init(2000);

    titleScene.init();
    worldScene.init();

    enter();
}

pub fn event(ev: *const window.Event) void {
    sceneCall("event", .{ev});
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

var isDebug: bool = true;
pub fn update(delta: f32) void {
    if (window.isKeyRelease(.X)) isDebug = !isDebug;

    if (window.isKeyDown(.LEFT_ALT) and window.isKeyRelease(.ENTER)) {
        return window.toggleFullScreen();
    }

    if (fadeTimer) |*timer| {
        // 存在淡入淡出效果，地图和角色暂时不更新。
        if (timer.isRunningAfterUpdate(delta)) return;
        if (isFadeIn) {
            fadeTimer = null;
        } else {
            if (fadeOutEndCallback) |callback| callback();
            isFadeIn = true;
            timer.restart();
        }
        return;
    }
    sceneCall("update", .{delta});
}

pub fn render() void {
    camera.beginDraw();
    defer camera.endDraw();

    window.keepAspectRatio();

    sceneCall("render", .{});

    // 将文字先绘制上，后面的淡入淡出才会生效。
    camera.flushTextureAndText();
    if (fadeTimer) |*timer| {
        camera.mode = .local;
        defer camera.mode = .world;
        const percent = timer.elapsed / timer.duration;
        const alpha = if (isFadeIn) 1 - percent else percent;
        camera.drawRectangle(.init(.zero, window.size), .{ .w = alpha });
    }

    if (isDebug) drawDebugInfo();
}

var debutTextCount: u32 = 0;
fn drawDebugInfo() void {
    var buffer: [100]u8 = undefined;
    const format =
        \\帧率：{}
        \\帧时：{d:.2}
        \\用时：{d:.2}
        \\图片：{}
        \\文字：{}
        \\绘制：{}
    ;

    const text = zhu.format(&buffer, format, .{
        window.frameRate,
        window.frameDeltaPerSecond,
        window.usedDeltaPerSecond,
        camera.imageDrawCount(),
        // Debug 信息本身的次数也应该统计进去
        camera.textDrawCount() + debutTextCount,
        camera.gpuDrawCount() + 1,
    });

    var iterator = std.unicode.Utf8View.initUnchecked(text).iterator();
    var count: u32 = 0;
    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') continue;
        count += 1;
    }
    debutTextCount = count;

    camera.drawColorText(text, .init(10, 5), .green);
}

var fadeTimer: ?window.Timer = null;
var isFadeIn: bool = false;
var fadeOutEndCallback: ?*const fn () void = null;

pub fn fadeIn() void {
    isFadeIn = true;
    fadeTimer = .init(2);
}

pub fn fadeOut(callback: ?*const fn () void) void {
    isFadeIn = false;
    fadeTimer = .init(2);
    fadeOutEndCallback = callback;
}

fn sceneCall(comptime function: []const u8, args: anytype) void {
    switch (currentSceneType) {
        .title => window.call(titleScene, function, args),
        .world => window.call(worldScene, function, args),
    }
}
