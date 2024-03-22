const std = @import("std");
const engine = @import("../engine.zig");
const core = @import("core.zig");

pub const Direction = enum { north, south, west, east };
const speedUnit = 1000;

pub const Player = struct {
    x: usize,
    y: usize,
    bombNumber: usize = 0,
    type: core.MapType,

    pub fn genEnemy(x: usize, y: usize) Player {
        return init(x, y, .enemy);
    }

    pub fn genPlayer(x: usize, y: usize) Player {
        return init(x, y, .player1);
    }

    fn init(x: usize, y: usize, t: core.MapType) Player {
        return Player{
            .x = x * core.getMapUnit() * speedUnit,
            .y = y * core.getMapUnit() * speedUnit,
            .type = t,
        };
    }

    pub fn getCell(self: Player) engine.Vector {
        const unit = core.getMapUnit();
        return .{
            .x = (self.x / speedUnit + (unit / 2)) / unit,
            .y = (self.y / speedUnit + (unit / 2)) / unit,
        };
    }

    pub fn draw(self: Player) void {
        const x = self.x / speedUnit;
        core.drawXY(self.type, x, self.y / speedUnit);
    }

    pub fn toCollisionRec(self: Player) engine.Rectangle {
        return engine.Rectangle{
            .x = self.x / speedUnit + 5,
            .y = self.y / speedUnit + 5,
            .width = core.getMapUnit() - 10,
            .height = core.getMapUnit() - 7,
        };
    }
};
