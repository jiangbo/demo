const std = @import("std");

pub const Container = struct {
    gold: u32 = 0,
    keys: u32 = 0,
    potion: u32 = 0,
    armor: u32 = 0,
    weapon: u32 = 0,
    locked: bool = false,
    sector: u32 = 0,
    tile: u32 = 0,
};
pub var containers = std.BoundedArray(Container, 100).init(0);

pub const Door = struct {
    secret: bool = false,
    locked: bool = false,
    sector: u32 = 0,
    tile: u32 = 0,
};
pub var doors = std.BoundedArray(Door, 100).init(0) catch unreachable;

pub const Person = struct {
    name: std.BoundedArray(u8, 50),
    canMove: bool = false,
    sector: u32 = 0,
    tile: u32 = 0,
};
pub var persons = std.BoundedArray(Person, 100).init(0) catch unreachable;

pub const Player = struct {
    sector: u32 = 0,
    hitPoints: u32 = 0,
    maxHitPoints: u32 = 0,
    armor: u32 = 0,
    weapon: u32 = 0,
    gold: u32 = 0,
    keys: u32 = 0,
    potions: u32 = 0,
    experience: u32 = 0,
};
pub var player: Player = .{
    .gold = 25,
    .hitPoints = 10,
    .maxHitPoints = 10,
    .keys = 1,
};
