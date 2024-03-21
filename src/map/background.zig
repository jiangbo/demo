const std = @import("std");
const engine = @import("../engine.zig");
const core = @import("core.zig");

fn genBackground(map: *BackgroundMap, brickRate: usize) void {
    for (0..map.height) |y| {
        for (0..map.width) |x| {
            map.data[x + y * map.width] = if (core.isFixWall(x, y))
                core.MapUnit.init(.wall)
            else if (core.isFixSpace(x, y))
                core.MapUnit.init(.space)
            else if (engine.random(100) < brickRate)
                core.MapUnit.init(.brick)
            else
                core.MapUnit.init(.space);
        }
    }
}

pub const BackgroundMap = struct {
    width: usize = core.getWidth(),
    height: usize = core.getHeight(),
    unit: usize = core.getMapUnit(),
    data: []core.MapUnit,

    pub fn init(config: core.StageConfig) BackgroundMap {
        var map = BackgroundMap{ .data = core.getMapData() };
        genBackground(&map, config.brickRate);
        return map;
    }

    pub fn isCollisionX(self: BackgroundMap, x: usize, y: usize, rect: engine.Rectangle) bool {
        for (0..3) |i| {
            if (self.isCollision(x, y + i -| 1, rect)) return true;
        } else return false;
    }

    pub fn isCollisionY(self: BackgroundMap, x: usize, y: usize, rect: engine.Rectangle) bool {
        for (0..3) |i| {
            if (self.isCollision(x + i - 1, y, rect)) return true;
        } else return false;
    }

    pub fn isCollision(self: BackgroundMap, x: usize, y: usize, rect: engine.Rectangle) bool {
        const cell = self.data[x + y * self.width];
        if (!cell.contains(.wall) and !cell.contains(.brick)) return false;

        const rec = engine.Rectangle{ .x = x, .y = y, .width = 1, .height = 1 };
        return engine.isCollision(rec.scale(self.unit), rect);
    }

    fn explosion(self: *WorldMap, mapUnit: *MapUnit, index: usize) void {
        const time = engine.time();
        mapUnit.remove(.bomb);

        mapUnit.insertTime(.explosion, time);
        // 左
        doExplosion(&self.data[index -| 1], .fireX, time);
        // 右
        doExplosion(&self.data[index + 1], .fireX, time);
        // 上
        doExplosion(&self.data[index - width], .fireY, time);
        // 下
        doExplosion(&self.data[index + width], .fireY, time);
    }

    fn doExplosion(mapUnit: *core.MapUnit, mapType: MapType, time: usize) void {
        if (mapUnit.contains(.wall)) return;
        if (mapUnit.contains(.brick)) mapUnit.remove(.brick);
        mapUnit.insertTime(mapType, time);
    }

    pub fn draw(self: BackgroundMap) void {
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                self.data[x + y * self.width].draw(x, y);
            }
        }
    }

    pub fn size(self: BackgroundMap) usize {
        return self.width * self.height;
    }
};
