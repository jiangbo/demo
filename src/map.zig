const std = @import("std");
const engine = @import("engine.zig");

// 定义地图的类型

pub const MapType = enum(u8) {
    wall = 1 << 0,
    brick = 1 << 1,
    bomb = 1 << 2,
    power = 1 << 3,
};

pub const MapItem = enum(u8) {
    SPACE = ' ',
    WALL = '#',
    GOAL = '.',
    BLOCK = 'o',
    BLOCK_GOAL = 'O',
    MAN = 'p',
    MAN_GOAL = 'P',

    pub fn fromU8(value: u8) MapItem {
        return @enumFromInt(value);
    }

    pub fn toU8(self: MapItem) u8 {
        return @intFromEnum(self);
    }

    pub fn hasGoal(self: MapItem) bool {
        return self == .BLOCK_GOAL or self == .MAN_GOAL;
    }

    pub fn toImageIndex(self: MapItem) usize {
        return switch (self) {
            .SPACE => 4,
            .WALL => 1,
            .BLOCK => 2,
            .GOAL => 3,
            .BLOCK_GOAL => 2,
            .MAN => 0,
            .MAN_GOAL => 0,
        };
    }
};

var tilemap: engine.Tilemap = undefined;

pub fn init() void {
    tilemap = engine.Tilemap.init("map.png", 32);
}

pub fn deinit() void {
    tilemap.deinit();
}

pub const WorldMap = struct {
    width: usize = 0,
    height: usize = 0,
    data: []MapItem = undefined,
    allocator: std.mem.Allocator = undefined,

    pub fn init(allocator: std.mem.Allocator, level: usize) ?WorldMap {
        return doInit(allocator, level) catch |err| {
            std.log.err("init stage error: {}", .{err});
            return null;
        };
    }

    fn doInit(allocator: std.mem.Allocator, level: usize) !?WorldMap {
        const text = try engine.readStageText(allocator, level);
        defer allocator.free(text);

        var map = parseText(text) orelse return null;

        var index: usize = 0;
        map.data = try allocator.alloc(MapItem, map.size());
        for (text) |char| {
            if (char == '\r' or char == '\n') continue;
            map.data[index] = MapItem.fromU8(char);
            index += 1;
        }
        map.allocator = allocator;
        return map;
    }

    pub fn draw(_: WorldMap) void {
        tilemap.draw();
    }

    fn parseText(text: []const u8) ?WorldMap {
        var map = WorldMap{};

        var width: usize = 0;
        for (text) |char| {
            if (char == '\r') continue;
            if (char != '\n') {
                width += 1;
                continue;
            }

            if (map.height != 0 and map.width != width) {
                std.log.err("width error, {} vs {}", .{ map.width, width });
                return null;
            }
            map.width = width;
            width = 0;
            map.height += 1;
        }
        return map;
    }

    pub fn size(self: WorldMap) usize {
        return self.width * self.height;
    }

    pub fn hasCleared(self: WorldMap) bool {
        for (self.data) |value| {
            if (value == MapItem.BLOCK) {
                return false;
            }
        } else return true;
    }

    pub fn playerIndex(self: WorldMap) usize {
        return for (self.data, 0..) |value, index| {
            if (value == .MAN or value == .MAN_GOAL) break index;
        } else 0;
    }

    pub fn deinit(self: WorldMap) void {
        self.allocator.free(self.data);
    }
};
