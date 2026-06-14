const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");

pub const scene = struct {
    pub const Scene = enum { title, farm };

    pub var current: Scene = .title;
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

pub const clock = struct {
    pub const Period = component.time.Period;
    pub const minutesPerRealSecond: f32 = 10.0;

    pub var paused: bool = false;
    // 时钟速度，影响农场里所有按 delta 推进的系统。
    pub var speed: f32 = 1;

    pub var day: u32 = 1;
    pub var hour: u8 = 6;
    pub var minute: f32 = 0.0;
    pub var period: Period = .dawn;
    pub var restHours: ?u8 = null;

    pub fn reset() void {
        paused = false;
        speed = 1;
        day = 1;
        hour = 6;
        minute = 0.0;
        period = .dawn;
        restHours = null;
    }

    pub fn isDark() bool {
        return hour >= 18 or hour < 6;
    }

    pub fn takeRestHours() ?u8 {
        const result = restHours;
        restHours = null;
        return result;
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
        inventory,
        hotbar1,
        hotbar2,
        hotbar3,
        hotbar4,
        hotbar5,
        hotbar6,
        hotbar7,
        hotbar8,
        hotbar9,
        hotbar10,
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

    pub fn hotbarIndexPressed() ?u8 {
        const first: usize = @intFromEnum(Command.hotbar1);
        const last: usize = @intFromEnum(Command.hotbar10);
        for (first..last + 1) |value| {
            const command: Command = @enumFromInt(value);
            if (pressed(command)) return @intCast(value - first);
        }
        return null;
    }
};

pub const notice = struct {
    pub var timer: f32 = 0;
    pub var text: []const u8 = &.{};
    var buffer: [160]u8 = undefined;

    pub fn show(comptime fmt: []const u8, args: anytype) void {
        text = zhu.format(&buffer, fmt, args);
        timer = 2.0;
    }
};

pub const map = struct {
    pub const Id = component.map.Id;

    pub const Thing = union(enum) {
        crop: component.farm.Crop,
        chest: struct { opened: bool = false },
        rock: struct { hitCount: u8 = 0 },
    };

    pub const Tile = struct {
        ground: ?component.farm.Ground = null,
        thing: ?Thing = null,
    };

    pub const State = struct {
        initialized: bool = false,
        day: u32 = 1,
        tiles: []Tile = &.{},
    };

    pub const Transition = struct { target: Id, targetId: i32 };

    pub var pending: ?Transition = null;
    pub var states: std.EnumArray(Id, State) = .initFill(.{});

    pub fn takePending() ?Transition {
        const request = pending;
        pending = null;
        return request;
    }

    pub fn ensureState(id: Id, tileCount: usize) *State {
        const result = states.getPtr(id);
        if (result.initialized) return result;

        if (result.tiles.len == 0) {
            result.tiles = zhu.assets.oomAlloc(Tile, tileCount);
        }
        @memset(result.tiles, .{});
        result.initialized = true;
        result.day = clock.day;
        return result;
    }

    pub fn resetStates() void {
        for (std.enums.values(Id)) |id| {
            states.getPtr(id).initialized = false;
        }
    }
};

pub fn init() void {
    scene.current = .title;
    scene.pending = null;
    _ = scene.takeLoadSlot();
    clock.reset();
    input.mouseCaptured = false;
    notice.timer = 0;
    map.pending = null;
    std.log.info("context init scene={s}", .{@tagName(scene.current)});
}

pub fn deinit() void {
    for (std.enums.values(map.Id)) |id| {
        zhu.assets.free(map.states.getPtr(id).tiles);
    }
}

test "场景请求会等待到应用阶段才生效" {
    init();

    const requested: scene.Scene = .farm;
    scene.request(requested);

    try std.testing.expectEqual(scene.Scene.title, scene.current);
    try std.testing.expectEqual(requested, scene.pending.?);

    scene.apply();

    try std.testing.expectEqual(requested, scene.current);
    try std.testing.expectEqual(null, scene.pending);
}

test "应用前最后一次场景请求生效" {
    init();

    scene.request(.farm);
    scene.request(.title);
    scene.apply();

    try std.testing.expectEqual(scene.Scene.title, scene.current);
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

    clock.hour = 17;
    clock.minute = 59;
    try std.testing.expect(!clock.isDark());

    clock.hour = 18;
    clock.minute = 0;
    try std.testing.expect(clock.isDark());
}

test "时间暗时段在 06:00 结束" {
    init();

    clock.hour = 5;
    clock.minute = 59;
    try std.testing.expect(clock.isDark());

    clock.hour = 6;
    clock.minute = 0;
    try std.testing.expect(!clock.isDark());
}
