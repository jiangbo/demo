const std = @import("std");
const engine = @import("engine.zig");

pub const Player = struct {};
pub const Enemy = struct {};

pub const Position = struct { vec: engine.Vec = engine.Vec{} };
pub const Health = struct { current: i32, max: i32 };
pub const Name = struct { value: []const u8 };

pub const Sprite = struct {
    sheet: engine.SpriteSheet,
    index: usize = 0,
};
