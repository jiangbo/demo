const std = @import("std");
const zhu = @import("zhu");

pub const Position = zhu.gfx.Vector;
pub const Texture = zhu.gfx.Texture;
pub const TurnState = enum { wait, player, monster };
pub const Health = struct { current: i32, max: i32 };
pub const Name = struct { []const u8 };
