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
    space = 9,
    wall = 7,
    brick = 8,
    bomb = 2,
    power = 3,
};
const MapTypeSet = std.enums.EnumSet(MapType);

const width = 19;
const height = 15;
var data: [width * height]MapTypeSet = undefined;

pub fn drawEnum(mapType: MapType, x: usize, y: usize) void {
    tileMap.drawI(@intFromEnum(mapType), x, y);
}

pub const WorldMap = struct {
    width: usize = width,
    height: usize = height,
    data: []MapTypeSet,

    pub fn init(_: std.mem.Allocator, _: usize) ?WorldMap {
        const map = WorldMap{ .data = &data };
        return map.generateMap(stageData[0]);
    }

    fn generateMap(self: WorldMap, info: StageData) WorldMap {
        var bricks: [data.len]usize = undefined;
        var brickNumber: usize = 0;
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                self.data[x + y * width] = if (isFixWall(x, y))
                    MapTypeSet.initOne(.wall)
                else if (isFixSpace(x, y))
                    MapTypeSet.initOne(.space)
                else if (engine.random(100) < info.brickRate) label: {
                    bricks[brickNumber] = x << 16 | y;
                    brickNumber += 1;
                    break :label MapTypeSet.initOne(.brick);
                } else MapTypeSet.initOne(.space);
            }
        }
        generateItem(self, bricks[0..brickNumber], info);
        return self;
    }

    fn isFixWall(x: usize, y: usize) bool {
        if (x == 0 or y == 0) return true;
        if (x == width - 1 or y == height - 1) return true;
        if (x % 2 == 0 and y % 2 == 0) return true;
        return false;
    }

    fn isFixSpace(x: usize, y: usize) bool {
        return y + x < 4;
    }

    fn generateItem(self: WorldMap, bricks: []usize, info: StageData) void {
        for (0..info.bomb + info.power) |i| {
            const swapped = engine.randomX(i, bricks.len);
            const tmp = bricks[i];
            bricks[i] = bricks[swapped];
            bricks[swapped] = tmp;
            const x = bricks[i] >> 16 & 0xFFFF;
            const item: MapType = if (i < info.power) .power else .bomb;
            self.data[x + (bricks[i] & 0xFFFF) * self.width].insert(item);
        }
    }

    pub fn draw(self: WorldMap) void {
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const value = data[x + y * self.width];
                if (value.contains(.wall)) drawEnum(.wall, x, y) //
                else if (value.contains(.brick)) drawEnum(.brick, x, y) //
                else {
                    drawEnum(.space, x, y);
                    if (value.contains(.power)) drawEnum(.power, x, y) //
                    else if (value.contains(.bomb)) drawEnum(.bomb, x, y);
                }
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
