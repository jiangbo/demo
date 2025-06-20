const std = @import("std");

const window = @import("zhu").window;
const gfx = @import("zhu").gfx;
const camera = @import("zhu").camera;

const titleScene = @import("title.zig");
const worldScene = @import("world.zig");

const SceneType = enum { title, world };
var currentSceneType: SceneType = .world;
var toSceneType: SceneType = .title;

pub fn init() void {
    const fontTexture = gfx.loadTexture("assets/font.png", .init(832, 832));
    window.initFont(.{
        .font = @import("zon/font.zon"),
        .texture = fontTexture,
    });

    camera.init(1000);

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

var isDebug: bool = true;
var isCamera: bool = false;
pub fn update(delta: f32) void {
    if (window.isKeyRelease(.X)) isDebug = !isDebug;
    if (window.isKeyRelease(.C)) isCamera = !isCamera;

    if (isCamera) controlCamera(delta);

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

const SPEED: f32 = 250;
pub fn controlCamera(delta: f32) void {
    const speed = SPEED * delta;

    if (window.isKeyDown(.W)) {
        camera.worldPosition = camera.worldPosition.addY(-speed);
    }

    if (window.isKeyDown(.S)) {
        camera.worldPosition = camera.worldPosition.addY(speed);
    }

    if (window.isKeyDown(.A)) {
        camera.worldPosition = camera.worldPosition.addX(-speed);
    }

    if (window.isKeyDown(.D)) {
        camera.worldPosition = camera.worldPosition.addX(speed);
    }
}

pub fn render() void {
    camera.beginDraw();
    defer camera.endDraw();

    window.keepAspectRatio();

    sceneCall("render", .{});

    // 将文字先绘制上，后面的淡入淡出才会生效。
    camera.flush();
    if (fadeTimer) |*timer| {
        const percent = timer.elapsed / timer.duration;
        const alpha = if (isFadeIn) 1 - percent else percent;
        camera.drawRectangle(.init(.zero, window.size), .{ .w = alpha });
    }

    if (isDebug) drawDebugInfo();
}

fn drawDebugInfo() void {
    var buffer: [100]u8 = undefined;
    const format =
        \\帧率：{}
        \\图片：{}
        \\文字：{}
        \\绘制：{}
    ;

    const text = std.fmt.bufPrint(&buffer, format, .{
        window.frameRate,
        camera.imageDrawCount(),
        // Debug 信息本身的次数也应该统计进去
        camera.textDrawCount() + debutTextCount,
        camera.gpuDrawCount() + 1,
    }) catch unreachable;

    var iterator = std.unicode.Utf8View.initUnchecked(text).iterator();
    var count: u32 = 0;
    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') continue;
        count += 1;
    }
    debutTextCount = count;

    camera.drawColorText(text, .init(10, 5), .green);
}

var debutTextCount: u32 = 0;

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
