const std = @import("std");
const zhu = @import("zhu");

pub const Position = zhu.gfx.Vector;
pub const Texture = zhu.gfx.Texture;
pub const TurnState = enum { wait, player, monster };
pub const Health = struct { current: i32, max: i32 };
pub const Name = struct { []const u8 };

pub const TilePosition = struct {
    x: u8,
    y: u8,
    pub fn equals(self: TilePosition, other: TilePosition) bool {
        return self.x == other.x and self.y == other.y;
    }
};
pub const TileRect = struct {
    x: u8,
    y: u8,
    w: u8,
    h: u8,

    pub fn intersect(r1: TileRect, r2: TileRect) bool {
        return r1.x < r2.x + r2.w and r1.x + r1.w > r2.x and
            r1.y < r2.y + r2.h and r1.y + r1.h > r2.y;
    }

    pub fn center(r: TileRect) TilePosition {
        return .{ .x = r.x + r.w / 2, .y = r.y + r.h / 2 };
    }
};
pub const WantToMove = struct { TilePosition };
