const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;

pub const TurnState = enum { wait, player, monster };
pub const Health = struct { current: i32, max: i32 };
