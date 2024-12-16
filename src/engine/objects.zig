const std = @import("std");
const constants = @import("constants.zig");

pub const Map = struct {
    type: u8,
    data: []u8,
};

pub const JsonMap = std.json.Parsed(Map);

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

const Containers = std.BoundedArray(Container, constants.MAX_CONTAINERS);
pub var containers = Containers.init(0) catch unreachable;

pub const Door = struct {
    secret: bool = false,
    locked: bool = false,
    sector: u32 = 0,
    tile: u32 = 0,
};

const Doors = std.BoundedArray(Door, constants.MAX_DOORS);
pub var doors = Doors.init(0) catch unreachable;

pub const Person = struct {
    name: std.BoundedArray(u8, 50),
    canMove: bool = false,
    sector: u32 = 0,
    tile: u32 = 0,
};

const Persons = std.BoundedArray(Person, constants.MAX_PEOPLE);
pub var persons = Persons.init(0) catch unreachable;

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
