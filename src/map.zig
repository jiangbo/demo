const std = @import("std");
const engine = @import("engine.zig");

var tileMap: engine.TileMap = undefined;

pub fn init() void {
    tileMap = engine.TileMap.init("map.png", 32);
}

pub fn deinit() void {
    tileMap.deinit();
}

const StageData = struct {
    enemy: usize,
    brickRate: usize,
    power: usize,
    bomb: usize,
};

const stageData = [_]StageData{
    .{ .enemy = 2, .brickRate = 90, .power = 4, .bomb = 6 },
    .{ .enemy = 3, .brickRate = 80, .power = 1, .bomb = 0 },
    .{ .enemy = 6, .brickRate = 30, .power = 0, .bomb = 1 },
};

// 定义地图的类型
pub const MapType = enum(u8) {
    space = 0,
    wall = 1 << 0,
    brick = 1 << 1,
    bomb = 1 << 2,
    power = 1 << 3,

    fn toTileMapIndex(self: MapType) usize {
        return switch (self) {
            .space => 9,
            .wall => 7,
            .brick => 8,
            .bomb => 10,
            .power => 11,
        };
    }
};

const width = 20;
const height = 15;
var data: [width * height]MapType = undefined;

fn generateMap(info: StageData) void {
    for (0..height) |y| {
        for (0..width) |x| {
            if (x == 0 or y == 0 or x == width - 1 or y == height - 1) {
                data[x + y * width] = .wall;
            } else if (x % 2 == 0 and y % 2 == 0) {
                data[x + y * width] = .wall;
            } else if (y + x < 4) {
                //
            } else {
                if (engine.random(100) < info.brickRate) {
                    data[x + y * width] = .brick;
                } else {
                    data[x + y * width] = .space;
                }
            }
        }
    }
}

pub const WorldMap = struct {
    width: usize = width,
    height: usize = height,
    data: []MapType = undefined,

    pub fn init(_: std.mem.Allocator, _: usize) ?WorldMap {
        generateMap(stageData[0]);
        return .{};
    }

    pub fn draw(_: WorldMap) void {
        for (0..height) |y| {
            for (0..width) |x| {
                const index = data[x + y * width].toTileMapIndex();
                tileMap.drawI(index, x, y);
            }
        }
    }

    pub fn size(self: WorldMap) usize {
        return self.width * self.height;
    }

    pub fn deinit(_: WorldMap) void {
        // self.allocator.free(self.data);
    }
};
