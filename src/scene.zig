const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const window = zhu.window;
const camera = zhu.camera;

const titleScene = @import("ui/title.zig");
const worldScene = @import("world.zig");
const battleScene = @import("battle/battle.zig");
const map = @import("map.zig");
const system = @import("system/system.zig");
const ui = @import("ui/ui.zig");
const input = @import("zon.zig").input;

const SceneType = enum { title, world, battle };
var currentSceneType: SceneType = .title;
var toSceneType: SceneType = .title;

var isHelp: bool = true;
var isDebug: bool = false;
var world: ecs.World = undefined;
// 场景负责保存应用分配器，并向需要分配内存的模块传递。
var allocator: zhu.Allocator = undefined;

pub fn init(allocator_: zhu.Allocator) void {
    allocator = allocator_;
    world = ecs.World.init(allocator_.raw);
    world.entity = world.createEntity();
    titleScene.init();
    ui.init();
    map.init(&world);
    battleScene.init(allocator_);

    titleScene.enter();
    fadeIn();
}

pub fn changeScene(sceneType: SceneType) void {
    toSceneType = sceneType;
    fadeOut(doChangeScene);
}

pub fn changeMap() void {
    fadeOut(doChangeMap);
}

fn doChangeMap() void {
    map.enter(&world, allocator, .{
        .portal = map.portalKey,
    });
    camera.directFollow(map.playerPosition(&world));
    camera.roundPosition(null);
}

fn doChangeScene() void {
    switch (currentSceneType) {
        .title => titleScene.exit(),
        .world => {},
        .battle => {},
    }
    currentSceneType = toSceneType;
    switch (currentSceneType) {
        .title => titleScene.enter(),
        .world => worldScene.enter(&world, allocator),
        .battle => battleScene.enter(&world),
    }
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
    switch (currentSceneType) {
        .title => if (titleScene.update(delta)) |req| switch (req) {
            .fadeOut => |done| fadeOut(done),
            .start => {
                worldScene.back = .none;
                changeScene(.world);
            },
            .load => |index| {
                worldScene.back = .{ .load = index };
                changeScene(.world);
            },
        },
        .world => worldScene.update(&world, delta),
        .battle => if (battleScene.update(&world, delta)) |request| {
            switch (request) {
                .world => {
                    worldScene.back = .battle;
                    changeScene(.world);
                },
                .title => changeScene(.title),
            }
        },
    }
}

pub fn draw() void {
    switch (currentSceneType) {
        .title => titleScene.draw(),
        .world => {
            system.render.draw(&world);

            camera.push(.window);
            ui.draw(&world);
            camera.pop();
        },
        .battle => battleScene.draw(&world),
    }

    if (fadeTimer) |*timer| {
        camera.push(.window);
        defer camera.pop();
        const percent = timer.progress();
        const alpha = if (isFadeIn) 1 - percent else percent;
        zhu.batch.drawRect(.init(.zero, window.size), .{
            .color = .rgba(0, 0, 0, alpha),
        });
    }

    camera.push(.window);
    defer camera.pop();
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

fn fadeIn() void {
    isFadeIn = true;
    fadeTimer = .init(1);
}

fn fadeOut(callback: ?*const fn () void) void {
    isFadeIn = false;
    fadeTimer = .init(1);
    fadeOutEndCallback = callback;
}

pub fn deinit() void {
    world.deinit();
    map.deinit(allocator);
    zhu.audio.setMusicState(.stopped);
    battleScene.deinit(allocator);
}
