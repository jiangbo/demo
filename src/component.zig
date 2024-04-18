const std = @import("std");
const engine = @import("engine.zig");

pub const Player = struct {};
pub const Enemy = struct {};
pub const Item = struct {};
pub const Amulet = struct {};

pub const Position = struct { vec: engine.Vec = engine.Vec{} };
pub const Health = struct { current: u32, max: u32 };
pub const Name = struct { value: [:0]const u8 };

pub const Attack = struct { attacker: engine.Entity, victim: engine.Entity };

pub const Sprite = struct {
    sheet: engine.SpriteSheet,
    index: usize = 0,
};
