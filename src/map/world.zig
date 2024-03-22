const std = @import("std");
const engine = @import("../engine.zig");
const core = @import("core.zig");
const Player = @import("player.zig").Player;

fn genMap(world: *World, config: core.StageConfig) void {
    var bricks: [core.getSize()]usize = undefined;
    var brickNumber: usize = 0;
    var floors: [core.getSize()]usize = undefined;
    var floorNumber: usize = 0;

    for (0..world.height) |y| {
        for (0..world.width) |x| {
            world.data[x + y * world.width] = if (core.isFixWall(x, y))
                core.MapUnit.init(.wall)
            else if (core.isFixSpace(x, y))
                core.MapUnit.init(.space)
            else if (engine.random(100) < config.brickRate) label: {
                bricks[brickNumber] = x << 16 | y;
                brickNumber += 1;
                break :label core.MapUnit.init(.brick);
            } else label: {
                floors[floorNumber] = x << 16 | y;
                floorNumber += 1;
                break :label core.MapUnit.init(.space);
            };
        }
    }
    genItem(world, bricks[0..brickNumber], config);
    genPlayer(world, floors[0..floorNumber], config);
}

fn genItem(self: *World, bricks: []usize, cfg: core.StageConfig) void {
    for (0..cfg.bomb + cfg.power) |i| {
        const swapped = engine.randomW(i, bricks.len);
        const tmp = bricks[i];
        bricks[i] = bricks[swapped];
        bricks[swapped] = tmp;
        const x = bricks[i] >> 16 & 0xFFFF;
        const item: core.MapType = if (i < cfg.power) .power else .item;
        self.data[x + (bricks[i] & 0xFFFF) * self.width].insert(item);
    }
}

fn genPlayer(world: *World, floors: []usize, cfg: core.StageConfig) void {
    for (0..cfg.enemy) |i| {
        const swapped = engine.randomW(i, floors.len);
        const tmp = floors[i];
        floors[i] = floors[swapped];
        floors[swapped] = tmp;
        const x = floors[i] >> 16 & 0xFFFF;
        world.players[1 + i] = Player.genEnemy(x, floors[i] & 0xFFFF);
    }
}

pub const World = struct {
    width: usize = core.getWidth(),
    height: usize = core.getHeight(),
    unit: usize,
    data: []core.MapUnit = core.getMapData(),
    players: []Player,

    pub fn init(config: core.StageConfig) ?World {
        const number = config.enemy + 1;
        const players = engine.allocator.alloc(Player, number) catch |e| {
            std.log.info("create players error: {}", .{e});
            return null;
        };

        var map = World{ .unit = core.getMapUnit(), .players = players };
        genMap(&map, config);
        return map;
    }

    pub fn update(self: *World) void {
        const time = engine.time();
        for (self.data, 0..) |*value, idx| {
            if (value.contains(.bomb)) {
                if (time > value.time + 3000) {
                    self.explosion(value, idx);
                }
            }
            if (value.contains(.explosion)) {
                if (time > value.time + 700) {
                    value.remove(.explosion);
                }
            }

            if (value.contains(.fireX)) {
                if (time > value.time + 700) {
                    value.remove(.fireX);
                }
            }

            if (value.contains(.fireY)) {
                if (time > value.time + 700) {
                    value.remove(.fireY);
                }
            }
        }
    }

    fn explosion(self: *World, mapUnit: *core.MapUnit, idx: usize) void {
        const time = engine.time();
        mapUnit.remove(.bomb);

        mapUnit.insertTimedType(.explosion, time);
        // 左
        doExplosion(&self.data[idx -| 1], .fireX, time);
        // 右
        doExplosion(&self.data[idx + 1], .fireX, time);
        // 上
        doExplosion(&self.data[idx - self.width], .fireY, time);
        // 下
        doExplosion(&self.data[idx + self.width], .fireY, time);
    }

    fn doExplosion(mapUnit: *core.MapUnit, mapType: core.MapType, time: usize) void {
        if (mapUnit.contains(.wall)) return;
        if (mapUnit.contains(.brick)) mapUnit.remove(.brick);
        mapUnit.insertTimedType(mapType, time);
    }

    pub fn isCollision(self: World, x: usize, y: usize, rect: engine.Rectangle) bool {
        const cell = self.index(x, y);
        if (!cell.contains(.wall) and !cell.contains(.brick)) return false;

        const rec = engine.Rectangle{ .x = x, .y = y, .width = 1, .height = 1 };
        return engine.isCollision(rec.scale(self.unit), rect);
    }

    pub fn draw(self: World) void {
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                self.data[x + y * self.width].draw(x, y);
            }
        }

        for (self.players) |value| value.draw();
    }

    fn index(self: World, x: usize, y: usize) core.MapUnit {
        return self.data[x + y * self.width];
    }

    pub fn indexRef(self: *World, x: usize, y: usize) *core.MapUnit {
        return &self.data[x + y * self.width];
    }

    pub fn size(self: World) usize {
        return self.width * self.height;
    }

    pub fn deinit(self: World) void {
        engine.allocator.free(self.players);
    }
};
