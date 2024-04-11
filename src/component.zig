const std = @import("std");
const engine = @import("engine.zig");

pub const Player = struct {};
pub const Enemy = struct {};

pub const Position = struct { vec: engine.Vec = engine.Vec{} };

pub const Sprite = struct {
    sheet: engine.SpriteSheet,
    index: usize = 0,
};
