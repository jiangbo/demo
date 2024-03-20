const std = @import("std");
const engine = @import("engine.zig");

var tileMap: engine.TileMap = undefined;

pub fn init() void {
    tileMap = engine.TileMap.init("map.png", 32);
}

pub fn deinit() void {
    tileMap.deinit();
}

const StageConfig = struct {
    enemy: usize,
    brickRate: usize,
    power: usize,
    bomb: usize,
};

const stageConfig = [_]StageConfig{
    .{ .enemy = 2, .brickRate = 90, .power = 4, .bomb = 6 },
    .{ .enemy = 3, .brickRate = 80, .power = 1, .bomb = 0 },
    .{ .enemy = 6, .brickRate = 30, .power = 0, .bomb = 1 },
};

// 定义地图的类型
pub const MapType = enum(u8) {
    space = 9,
    wall = 7,
    brick = 8,
    bomb = 10,
    item = 2,
    power = 3,
    fireX = 4,
    fireY = 5,
    explosion = 11,
};
const MapTypeSet = std.enums.EnumSet(MapType);

const MapUnit = struct {
    set: std.enums.EnumSet(MapType),
    time: usize = 0,

    fn init(mapType: MapType) MapUnit {
        return .{ .set = std.enums.EnumSet(MapType).initOne(mapType) };
    }

    fn contains(self: MapUnit, mapType: MapType) bool {
        return self.set.contains(mapType);
    }

    fn remove(self: *MapUnit, mapType: MapType) void {
        self.set.remove(mapType);
    }

    fn insert(self: *MapUnit, mapType: MapType) void {
        self.set.insert(mapType);
    }

    fn insertTime(self: *MapUnit, mapType: MapType, time: usize) void {
        self.insert(mapType);
        self.time = time;
    }
};

const width = 19;
const height = 15;
var data: [width * height]MapUnit = undefined;

pub fn drawEnum(mapType: MapType, x: usize, y: usize) void {
    tileMap.drawI(@intFromEnum(mapType), x, y);
}

const RoleType = enum(u8) { player1 = 1, player2 = 2, enemy = 6 };

var maxBombNumber: usize = 1;

pub const Role = struct {
    x: usize,
    y: usize,
    bombNumer: usize = 0,
    type: RoleType = .enemy,

    pub fn getCell(self: Role) engine.Vector {
        return .{
            .x = (self.x / speedUnit + (tileMap.unit / 2)) / tileMap.unit,
            .y = (self.y / speedUnit + (tileMap.unit / 2)) / tileMap.unit,
        };
    }

    fn toCollisionRec(self: Role) engine.Rectangle {
        return engine.Rectangle{
            .x = self.x / speedUnit + 5,
            .y = self.y / speedUnit + 5,
            .width = tileMap.unit - 10,
            .height = tileMap.unit - 7,
        };
    }
};

const speedUnit = 1000;

pub const WorldMap = struct {
    width: usize = width,
    height: usize = height,
    data: []MapUnit,
    roles: []Role,

    pub fn init(_: usize) ?WorldMap {
        const number = stageConfig[0].enemy + 1;
        const roles = engine.allocator.alloc(Role, number) catch |e| {
            std.log.info("create role error: {}", .{e});
            return null;
        };

        roles[0] = .{
            .x = 1 * tileMap.unit * speedUnit,
            .y = 1 * tileMap.unit * speedUnit,
            .bombNumer = maxBombNumber,
            .type = .player1,
        };

        const map = WorldMap{ .data = &data, .roles = roles };
        map.generateMap(stageConfig[0]);
        return map;
    }

    fn generateMap(self: WorldMap, config: StageConfig) void {
        var bricks: [data.len]usize = undefined;
        var brickNumber: usize = 0;
        var floors: [data.len]usize = undefined;
        var floorNumber: usize = 0;

        for (0..self.height) |y| {
            for (0..self.width) |x| {
                self.data[x + y * width] = if (isFixWall(x, y))
                    MapUnit.init(.wall)
                else if (isFixSpace(x, y))
                    MapUnit.init(.space)
                else if (engine.random(100) < config.brickRate) label: {
                    bricks[brickNumber] = x << 16 | y;
                    brickNumber += 1;
                    break :label MapUnit.init(.brick);
                } else label: {
                    floors[floorNumber] = x << 16 | y;
                    floorNumber += 1;
                    break :label MapUnit.init(.space);
                };
            }
        }
        generateItem(self, bricks[0..brickNumber], config);
        generateRole(self, floors[0..floorNumber], config);
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

    fn generateItem(self: WorldMap, bricks: []usize, cfg: StageConfig) void {
        for (0..cfg.bomb + cfg.power) |i| {
            const swapped = engine.randomW(i, bricks.len);
            const tmp = bricks[i];
            bricks[i] = bricks[swapped];
            bricks[swapped] = tmp;
            const x = bricks[i] >> 16 & 0xFFFF;
            const item: MapType = if (i < cfg.power) .power else .item;
            self.data[x + (bricks[i] & 0xFFFF) * self.width].insert(item);
        }
    }

    fn generateRole(self: WorldMap, floors: []usize, cfg: StageConfig) void {
        for (0..cfg.enemy) |i| {
            const swapped = engine.randomW(i, floors.len);
            const tmp = floors[i];
            floors[i] = floors[swapped];
            floors[swapped] = tmp;
            self.roles[1 + i] = .{
                .x = (floors[i] >> 16 & 0xFFFF) * tileMap.unit * speedUnit,
                .y = (floors[i] & 0xFFFF) * tileMap.unit * speedUnit,
            };
        }
    }

    pub fn player1(self: WorldMap) *Role {
        return &self.roles[0];
    }

    pub fn update(self: *WorldMap) void {
        const time = engine.time();
        for (self.data, 0..) |*value, index| {
            if (value.contains(.bomb)) {
                if (time > value.time + 3000) {
                    self.explosion(value, index);
                }
            }
        }
        // const time = engine.time();
        // if (self.player1().bomb) |bomb| {
        //     if (time > bomb.time + 3000) {
        //         self.explosion(self.player1());
        //     }

        //     if (self.player1().bomb.?.isExplosion) {
        //         self.player1().*.bomb = null;
        //         self.data[bomb.x + bomb.y * width].remove(.bomb);
        //     }
        // }

        // for (&self.explosionList) |*value| {
        //     if (!value.isVisible) continue;
        //     if (time > value.time + 700) value.isVisible = false;
        // }
    }

    pub fn isCollisionX(self: WorldMap, x: usize, y: usize, role: Role) bool {
        for (0..3) |i| {
            if (self.isCollision(x, y + i -| 1, role)) return true;
        } else return false;
    }

    pub fn isCollisionY(self: WorldMap, x: usize, y: usize, role: Role) bool {
        for (0..3) |i| {
            if (self.isCollision(x + i - 1, y, role)) return true;
        } else return false;
    }

    pub fn isCollision(self: WorldMap, x: usize, y: usize, role: Role) bool {
        const cell = self.data[x + y * width];
        if (!cell.contains(.wall) and !cell.contains(.brick)) return false;

        const rec = engine.Rectangle{
            .x = x * tileMap.unit,
            .y = y * tileMap.unit,
            .width = tileMap.unit,
            .height = tileMap.unit,
        };
        return engine.isCollision(rec, role.toCollisionRec());
    }

    pub fn setBomb(self: *WorldMap, player: *Role) void {
        if (player.bombNumer >= maxBombNumber) return;

        const pos = player.getCell();
        const cell = &self.data[pos.x + pos.y * width];
        if (!cell.contains(.wall) and !cell.contains(.brick)) {
            cell.insertTime(.bomb, engine.time());
        }
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

    fn doExplosion(mapUnit: *MapUnit, mapType: MapType, time: usize) void {
        if (mapUnit.contains(.wall)) return;
        if (mapUnit.contains(.brick)) mapUnit.remove(.brick);
        mapUnit.insertTime(mapType, time);
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

        // for (self.explosionList) |value| {
        //     if (!value.isVisible) continue;
        //     drawEnum(value.type, value.x, value.y);
        // }

        for (self.roles) |value| {
            const x = value.x / speedUnit;
            tileMap.drawXY(x, value.y / speedUnit, @intFromEnum(value.type));
        }
    }

    pub fn size(self: WorldMap) usize {
        return self.width * self.height;
    }

    pub fn deinit(self: *WorldMap) void {
        engine.allocator.free(self.roles);
    }
};
