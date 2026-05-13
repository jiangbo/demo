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
    pendingScene = scene;
}

pub fn applyPendingScene() void {
    if (pendingScene) |scene| {
        currentScene = scene;
        pendingScene = null;
    }
}

test "测试场景切换" {
    init();

    requestScene(.farm);
    requestScene(.title);
    applyPendingScene();

    try std.testing.expectEqual(Scene.title, currentScene);
    try std.testing.expectEqual(@as(?Scene, null), pendingScene);
}
