const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;

pub const TurnState = enum { wait, player, monster };
