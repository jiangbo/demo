const std = @import("std");
const engine = @import("../engine.zig");

var tilemap: engine.Tilemap = undefined;

pub fn init() void {
    tilemap = engine.Tilemap.init("map.png", 32);
}

pub fn deinit() void {
    tilemap.deinit();
}

pub const BackMapType = enum(u8) {
    space = 9,
    wall = 7,
    brick = 8,
    item = 2,
    power = 3,
    bomb = 10,
    fireX = 4,
    fireY = 5,
    explosion = 11,
};

pub const StageConfig = struct {
    enemy: usize,
    brickRate: usize,
    power: usize,
    bomb: usize,
};

pub const ForeMapType = enum(u8) {};

const width = 19;
const height = 15;
var data: [width * height]MapUnit = undefined;

pub fn getWidth() usize {
    return width;
}

pub fn getHeight() usize {
    return height;
}

pub fn getMapData() []MapUnit {
    return data;
}

pub fn getMapUnit() usize {
    return tilemap.unit;
}

pub fn isFixWall(x: usize, y: usize) bool {
    if (x == 0 or y == 0) return true;
    if (x == width - 1 or y == height - 1) return true;
    if (x % 2 == 0 and y % 2 == 0) return true;
    return false;
}

pub fn isFixSpace(x: usize, y: usize) bool {
    return y + x < 4;
}

pub fn drawEnum(mapType: BackMapType, x: usize, y: usize) void {
    tilemap.drawI(@intFromEnum(mapType), x, y);
}

const ForeMapTypes = std.enums.EnumSet(ForeMapType);
const MapUnit = struct {
    backTypes: std.enums.EnumSet(BackMapType),
    foreTypes: ForeMapTypes = ForeMapTypes.initEmpty(),
    time: usize = std.math.maxInt(usize),

    fn init(back: BackMapType) MapUnit {
        return .{ .set = std.enums.EnumSet(BackMapType).initOne(back) };
    }

    pub fn contains(self: MapUnit, back: BackMapType) bool {
        return self.set.contains(back);
    }

    fn remove(self: *MapUnit, back: BackMapType) void {
        self.set.remove(back);
    }

    fn insert(self: *MapUnit, mapType: BackMapType) void {
        self.set.insert(mapType);
    }

    fn insertTime(self: *MapUnit, mapType: BackMapType, time: usize) void {
        self.insert(mapType);
        self.time = time;
    }

    pub fn draw(self: MapUnit, x: usize, y: usize) void {
        if (self.contains(.wall)) drawEnum(.wall, x, y) //
        else if (self.contains(.brick)) drawEnum(.brick, x, y) //
        else {
            drawEnum(.space, x, y);
            if (self.contains(.power)) drawEnum(.power, x, y) //
            else if (self.contains(.bomb)) drawEnum(.bomb, x, y);
        }
    }
};
