const std = @import("std");
const engine = @import("../engine.zig");
const core = @import("core.zig");

// 定义地图的类型
pub const MapType = enum(u8) {
    bomb = 10,
    fireX = 4,
    fireY = 5,
    explosion = 11,
};

const PlayerType = enum(u8) { player1 = 1, player2 = 2, enemy = 6 };

var maxBombNumber: usize = 1;

pub const Player = struct {
    x: usize,
    y: usize,
    unit: usize,
    bombNumer: usize = 0,
    type: PlayerType = .enemy,

    pub fn getCell(self: Player) engine.Vector {
        const unit = core.getMapUnit();
        return .{
            .unit = unit,
            .x = (self.x / speedUnit + (unit / 2)) / unit,
            .y = (self.y / speedUnit + (unit / 2)) / unit,
        };
    }

    fn toCollisionRec(self: Player) engine.Rectangle {
        return engine.Rectangle{
            .x = self.x / speedUnit + 5,
            .y = self.y / speedUnit + 5,
            .width = core.getMapUnit() - 10,
            .height = core.getMapUnit() - 7,
        };
    }
};

const speedUnit = 1000;

pub const ForegroundMap = struct {
    // width: usize = core.getWidth(),
    // height: usize = core.getHeight(),
    players: []Player,

    pub fn init(config: core.StageConfig) ?ForegroundMap {
        const number = config.enemy + 1;
        const players = engine.allocator.alloc(Player, number) catch |e| {
            std.log.info("create players error: {}", .{e});
            return null;
        };

        players[0] = .{
            .x = core.getMapUnit() * speedUnit,
            .y = core.getMapUnit() * speedUnit,
            .type = .player1,
        };

        return ForegroundMap{ .players = players };
    }

    pub fn player1(self: ForegroundMap) *Player {
        return &self.players[0];
    }

    pub fn update(self: *ForegroundMap) void {
        const time = engine.time();
        for (self.data, 0..) |*value, index| {
            if (value.contains(.bomb)) {
                if (time > value.time + 3000) {
                    self.explosion(value, index);
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

    pub fn setBomb(self: *ForegroundMap, player: *Player) void {
        if (player.bombNumer >= maxBombNumber) return;

        const pos = player.getCell();
        const cell = &self.data[pos.x + pos.y * width];
        if (!cell.contains(.wall) and !cell.contains(.brick)) {
            cell.insertTime(.bomb, engine.time());
        }
    }

    pub fn draw(self: ForegroundMap) void {
        for (self.roles) |value| {
            const x = value.x / speedUnit;
            tileMap.drawXY(x, value.y / speedUnit, @intFromEnum(value.type));
        }
    }

    pub fn size(self: WorldMap) usize {
        return self.width * self.height;
    }

    pub fn deinit(self: *ForegroundMap) void {
        engine.allocator.free(self.roles);
    }
};
