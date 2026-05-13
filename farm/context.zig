const std = @import("std");

pub const Scene = enum { title, farm };

const Config = struct {
    scene: Scene = .title,
    time_scale: f32 = 1,
};

const config: Config = @import("zon/context.zon");

pub var currentScene: Scene = config.scene;
pub var pendingScene: ?Scene = null;
pub var paused: bool = false;
pub var timeScale: f32 = config.time_scale;
pub var showEngineDebug: bool = false;
pub var showGameDebug: bool = false;
pub var uiWantCaptureMouse: bool = false;
pub var uiWantCaptureKeyboard: bool = false;

pub fn init() void {
    currentScene = config.scene;
    pendingScene = null;
    paused = false;
    timeScale = config.time_scale;
    showEngineDebug = false;
    showGameDebug = false;
    uiWantCaptureMouse = false;
    uiWantCaptureKeyboard = false;
    std.log.info("context init scene={s}", .{@tagName(currentScene)});
}

pub fn deinit() void {}

pub fn requestScene(scene: Scene) void {
    std.log.debug("request scene: {s} -> {s}", .{
        @tagName(currentScene),
        @tagName(scene),
    });
    pendingScene = scene;
}

pub fn applyPendingScene() void {
    if (pendingScene) |scene| {
        std.log.info("apply scene: {s} -> {s}", .{
            @tagName(currentScene),
            @tagName(scene),
        });
        currentScene = scene;
        pendingScene = null;
    }
}

test "场景请求会等待到应用阶段才生效" {
    init();

    requestScene(.farm);

    try std.testing.expectEqual(Scene.title, currentScene);
    try std.testing.expectEqual(Scene.farm, pendingScene.?);

    applyPendingScene();

    try std.testing.expectEqual(Scene.farm, currentScene);
    try std.testing.expectEqual(@as(?Scene, null), pendingScene);
}

test "应用前最后一次场景请求生效" {
    init();

    requestScene(.farm);
    requestScene(.title);
    applyPendingScene();

    try std.testing.expectEqual(Scene.title, currentScene);
    try std.testing.expectEqual(@as(?Scene, null), pendingScene);
}
