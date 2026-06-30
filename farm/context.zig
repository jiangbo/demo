const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");

pub const clock = struct {
    pub const Period = component.time.Period;
    pub const minutesPerRealSecond: f32 = 10.0;

    pub var paused: bool = false;
    // 时钟倍率，只影响游戏内时间流逝。
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

pub const notice = struct {
    pub const Channel = enum { world, item };

    pub const State = struct {
        timer: f32 = 0,
        text: []const u8 = &.{},
        buffer: [192]u8 = undefined,
    };

    pub var states: std.EnumArray(Channel, State) = .initFill(.{});

    pub fn show(channel: Channel, comptime fmt: []const u8, args: anytype) void {
        const current = states.getPtr(channel);
        current.text = zhu.format(&current.buffer, fmt, args);
        current.timer = 2.0;
    }

    pub fn state(channel: Channel) *State {
        return states.getPtr(channel);
    }
};

pub const map = struct {
    pub const Id = component.map.Id;
    pub const ProductState = struct {
        product: component.item.Product,
        health: component.item.Health,
    };

    pub const Thing = union(enum) {
        gone,
        crop: component.farm.Crop,
        chest: component.item.Chest,
        product: ProductState,
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
    clock.reset();
    notice.states = .initFill(.{});
    map.pending = null;
}

pub fn deinit() void {
    for (std.enums.values(map.Id)) |id| {
        zhu.assets.free(map.states.getPtr(id).tiles);
    }
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
