const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");

pub const scene = struct {
    pub const Scene = enum { title, farm };

    pub var current: Scene = config.scene;
    pub var pending: ?Scene = null;
    var pendingLoadSlot: ?usize = null;

    pub fn request(next: Scene) void {
        std.log.debug("request scene: {s} -> {s}", .{
            @tagName(current),
            @tagName(next),
        });
        pending = next;
    }

    pub fn requestNewGame() void {
        pendingLoadSlot = null;
        request(.farm);
    }

    pub fn requestLoad(slot: usize) void {
        pendingLoadSlot = slot;
        request(.farm);
    }

    pub fn takeLoadSlot() ?usize {
        const slot = pendingLoadSlot;
        pendingLoadSlot = null;
        return slot;
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
    pub const Period = component.time.Period;

    pub var paused: bool = false;
    // 整体更新倍率，影响场景里所有按 delta 推进的系统
    pub var scale: f32 = config.time_scale;

    pub var day: u32 = 1;
    pub var hour: u8 = 6;
    pub var minute: f32 = 0.0;
    pub var period: Period = .dawn;

    pub fn reset() void {
        paused = false;
        scale = config.time_scale;
        day = 1;
        hour = 6;
        minute = 0.0;
        period = .dawn;
    }

    pub fn isDark() bool {
        return hour >= 18 or hour < 6;
    }
};

pub const debug = struct {
    pub var showGame: bool = false;
};

pub const ui = struct {
    pub var wantCaptureMouse: bool = false;
    pub var wantCaptureKeyboard: bool = false;

    pub fn wantCapture() bool {
        return wantCaptureMouse or wantCaptureKeyboard;
    }

    pub fn mouseCaptured() bool {
        return wantCaptureMouse;
    }
};

pub const input = struct {
    pub const Command = enum {
        moveLeft,
        moveRight,
        moveUp,
        moveDown,
        pause,
        interact,
        toolbar1,
        toolbar2,
        toolbar3,
        toolbar4,
        toolbar5,
        toolbar6,
        toolbar7,
        toolbar8,
        toolbar9,
        toolbar10,
    };

    pub var mouseCaptured: bool = false;

    const Entry = struct { type: Command, value: []const zhu.key.Code };
    const zon: []const Entry = @import("zon/input.zon");
    const keys = zhu.enumArrayByType(Entry, zon);
    const Mouse = zhu.mouse.Button;

    pub fn held(command: Command) bool {
        return zhu.key.anyHeld(keys.get(command));
    }

    pub fn pressed(command: Command) bool {
        return zhu.key.anyPressed(keys.get(command));
    }

    pub fn released(command: Command) bool {
        return zhu.key.anyReleased(keys.get(command));
    }

    pub fn mouseHeld(button: Mouse) bool {
        if (mouseCaptured) return false;
        return zhu.mouse.held(button);
    }

    pub fn mousePressed(button: Mouse) bool {
        if (mouseCaptured) return false;
        return zhu.mouse.pressed(button);
    }

    pub fn mouseReleased(button: Mouse) bool {
        if (mouseCaptured) return false;
        return zhu.mouse.released(button);
    }

    pub fn toolbarIndexPressed() ?u8 {
        const first: usize = @intFromEnum(Command.toolbar1);
        const last: usize = @intFromEnum(Command.toolbar10);
        for (first..last + 1) |value| {
            const command: Command = @enumFromInt(value);
            if (pressed(command)) return @intCast(value - first);
        }
        return null;
    }
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
    _ = scene.takeLoadSlot();
    time.reset();
    debug.showGame = false;
    ui.wantCaptureMouse = false;
    ui.wantCaptureKeyboard = false;
    input.mouseCaptured = false;
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
    try std.testing.expectEqual(null, scene.pending);
}

test "应用前最后一次场景请求生效" {
    init();

    const first: scene.Scene = if (config.scene == .title) .farm else .title;
    scene.request(first);
    scene.request(config.scene);
    scene.apply();

    try std.testing.expectEqual(config.scene, scene.current);
    try std.testing.expectEqual(null, scene.pending);
}

test "读档请求会携带一次性槽位" {
    init();

    scene.requestLoad(4);

    try std.testing.expectEqual(scene.Scene.farm, scene.pending.?);
    try std.testing.expectEqual(4, scene.takeLoadSlot().?);
    try std.testing.expectEqual(null, scene.takeLoadSlot());
}

test "地图切换请求会被 take 消费" {
    init();

    map.pending = .{
        .target = component.map.Id.town,
        .targetId = 3,
    };

    const transition = map.takePending().?;
    try std.testing.expectEqual(component.map.Id.town, transition.target);
    try std.testing.expectEqual(3, transition.targetId);
    try std.testing.expectEqual(null, map.pending);
}

test "时间暗时段从 18:00 开始" {
    init();

    time.hour = 17;
    time.minute = 59;
    try std.testing.expect(!time.isDark());

    time.hour = 18;
    time.minute = 0;
    try std.testing.expect(time.isDark());
}

test "时间暗时段在 06:00 结束" {
    init();

    time.hour = 5;
    time.minute = 59;
    try std.testing.expect(time.isDark());

    time.hour = 6;
    time.minute = 0;
    try std.testing.expect(!time.isDark());
}
