const std = @import("std");

const component = @import("component.zig");

pub const scene = struct {
    pub const Scene = enum { title, farm };

    pub var current: Scene = config.scene;
    pub var pending: ?Scene = null;

    pub fn request(next: Scene) void {
        std.log.debug("request scene: {s} -> {s}", .{
            @tagName(current),
            @tagName(next),
        });
        pending = next;
    }

    pub fn apply() void {
        if (pending) |next| {
            std.log.info("apply scene: {s} -> {s}", .{
                @tagName(current),
                @tagName(next),
            });
            current = next;
            pending = null;
        }
    }
};

pub const time = struct {
    pub var paused: bool = false;
    pub var scale: f32 = config.time_scale;
};

pub const debug = struct {
    pub var showEngine: bool = false;
    pub var showGame: bool = false;
};

pub const ui = struct {
    pub var wantCaptureMouse: bool = false;
    pub var wantCaptureKeyboard: bool = false;
};

pub const map = struct {
    pub const Transition = struct {
        target: component.map.Id,
        targetId: i32,
    };

    pub var pending: ?Transition = null;

    pub fn takePending() ?Transition {
        const request = pending;
        pending = null;
        return request;
    }
};

const Config = struct {
    scene: scene.Scene = .title,
    time_scale: f32 = 1,
};

const config: Config = @import("zon/context.zon");

pub fn init() void {
    scene.current = config.scene;
    scene.pending = null;
    time.paused = false;
    time.scale = config.time_scale;
    debug.showEngine = false;
    debug.showGame = false;
    ui.wantCaptureMouse = false;
    ui.wantCaptureKeyboard = false;
    map.pending = null;
    std.log.info("context init scene={s}", .{@tagName(scene.current)});
}

pub fn deinit() void {}

test "场景请求会等待到应用阶段才生效" {
    init();

    const requested: scene.Scene = if (config.scene == .title) .farm else .title;
    scene.request(requested);

    try std.testing.expectEqual(config.scene, scene.current);
    try std.testing.expectEqual(requested, scene.pending.?);

    scene.apply();

    try std.testing.expectEqual(requested, scene.current);
    try std.testing.expectEqual(@as(?scene.Scene, null), scene.pending);
}

test "应用前最后一次场景请求生效" {
    init();

    const first: scene.Scene = if (config.scene == .title) .farm else .title;
    scene.request(first);
    scene.request(config.scene);
    scene.apply();

    try std.testing.expectEqual(config.scene, scene.current);
    try std.testing.expectEqual(@as(?scene.Scene, null), scene.pending);
}

test "地图切换请求会被 take 消费" {
    init();

    map.pending = .{
        .target = component.map.Id.town,
        .targetId = 3,
    };

    const transition = map.takePending().?;
    try std.testing.expectEqual(component.map.Id.town, transition.target);
    try std.testing.expectEqual(@as(i32, 3), transition.targetId);
    try std.testing.expectEqual(@as(?map.Transition, null), map.pending);
}
