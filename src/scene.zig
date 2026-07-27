const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const window = zhu.window;
const camera = zhu.camera;

const titleScene = @import("ui/title.zig");
const worldScene = @import("world.zig");
const battleScene = @import("battle/battle.zig");
const input = @import("zon.zig").input;
const storage = @import("storage.zig");

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
    world.addAll(world.entity, .{
        storage.DeadActors.empty,
        storage.OpenedChests.initEmpty(),
        storage.Progress{},
        storage.Stats{},
        storage.Inventory{},
    });
    titleScene.init();
    worldScene.init(allocator_);
    battleScene.init();

    sceneCall("enter", .{});
    fadeIn();
}

pub fn loadWorld(index: u8) !void {
    try worldScene.load(&world, index);
}

pub fn changeScene(sceneType: SceneType) void {
    toSceneType = sceneType;
    fadeOut(doChangeScene);
}

pub fn changeMap() void {
    fadeOut(doChangeMap);
}

fn doChangeMap() void {
    worldScene.changeMap(&world, allocator);
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
    switch (currentSceneType) {
        .title => if (titleScene.update(delta)) |req| switch (req) {
            .fadeOut => |done| fadeOut(done),
            .start => {
                worldScene.back = .none;
                changeScene(.world);
            },
            .load => |index| {
                worldScene.load(&world, index) catch return;
                worldScene.back = .load;
                changeScene(.world);
            },
        },
        .world => worldScene.update(&world, delta),
        .battle => battleScene.update(&world, delta),
    }
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
    worldScene.deinit(allocator);
}

fn sceneCall(comptime function: []const u8, args: anytype) void {
    switch (currentSceneType) {
        .title => window.call(titleScene, function, args),
        .world => if (comptime std.mem.eql(u8, function, "enter")) {
            window.call(
                worldScene,
                function,
                .{ &world, allocator } ++ args,
            );
        } else if (comptime std.mem.eql(u8, function, "update") or
            std.mem.eql(u8, function, "draw"))
        {
            window.call(worldScene, function, .{&world} ++ args);
        } else window.call(worldScene, function, args),
        .battle => if (comptime std.mem.eql(u8, function, "enter") or
            std.mem.eql(u8, function, "update") or
            std.mem.eql(u8, function, "draw"))
        {
            window.call(battleScene, function, .{&world} ++ args);
        } else {
            window.call(battleScene, function, args);
        },
    }
}
