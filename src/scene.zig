const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const camera = zhu.camera;

const titleScene = @import("title.zig");
const worldScene = @import("world.zig");
const battleScene = @import("battle.zig");
const input = @import("input.zig");

const SceneType = enum { title, world, battle };
var currentSceneType: SceneType = .title;
var toSceneType: SceneType = .title;

var isHelp: bool = true;
var isDebug: bool = false;

pub fn init() void {
    titleScene.init();
    worldScene.init();
    battleScene.init();

    sceneCall("enter", .{});
}

pub fn changeScene(sceneType: SceneType) void {
    toSceneType = sceneType;
    fadeOut(doChangeScene);
}

pub fn changeMap() void {
    fadeOut(worldScene.changeMap);
}

fn doChangeScene() void {
    sceneCall("exit", .{});
    currentSceneType = toSceneType;
    sceneCall("enter", .{});
}

pub fn update(delta: f32) void {
    if (input.released(.help)) isHelp = !isHelp;
    if (input.released(.debug)) isDebug = !isDebug;

    if (zhu.key.held(.LEFT_ALT) and zhu.key.released(.ENTER)) {
        return window.toggleFullScreen();
    }

    if (fadeTimer) |*timer| {
        // 存在淡入淡出效果，地图和角色暂时不更新。
        if (timer.updateRunning(delta)) return;
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

pub fn draw() void {
    sceneCall("draw", .{});

    if (fadeTimer) |*timer| {
        camera.push(.window);
        defer camera.pop();
        const percent = timer.progress();
        const alpha = if (isFadeIn) 1 - percent else percent;
        zhu.batch.drawRect(.init(.zero, window.size), .{
            .color = .rgba(0, 0, 0, alpha),
        });
    }
    if (isHelp) drawHelpInfo() else if (isDebug) drawDebugInfo();
}

fn drawHelpInfo() void {
    const text =
        \\按键说明：
        \\上：W，下：S，左：A，右：D
        \\确定：F，取消：Q，菜单：E
        \\帮助：H  按一次打开，再按一次关掉
        \\作者：jiangbo4444
    ;

    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    zhu.text.draw(text, .xy(10, 5), .{ .color = .green });
}

fn drawDebugInfo() void {
    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    zhu.debug.draw(&.{});
}

var fadeTimer: ?zhu.Timer = null;
var isFadeIn: bool = false;
var fadeOutEndCallback: ?*const fn () void = null;

pub fn fadeIn() void {
    isFadeIn = true;
    fadeTimer = .init(1);
}

pub fn fadeOut(callback: ?*const fn () void) void {
    isFadeIn = false;
    fadeTimer = .init(1);
    fadeOutEndCallback = callback;
}

pub fn deinit() void {
    sceneCall("deinit", .{});
}

fn sceneCall(comptime function: []const u8, args: anytype) void {
    switch (currentSceneType) {
        .title => window.call(titleScene, function, args),
        .world => window.call(worldScene, function, args),
        .battle => window.call(battleScene, function, args),
    }
}
