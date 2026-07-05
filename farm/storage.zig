const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const Clock = @import("resource/Clock.zig");
const Speed = @import("resource/Speed.zig");
const World = zhu.ecs.World;

pub const Summary = struct { day: u32 = 0, timestamp: i64 = 0 };

pub const Slot = union(enum) { empty, valid: Summary };

pub const Config = struct {
    speed: f32 = 1,
    music: f32 = 1,
    sound: f32 = 1,
};

pub const Player = struct {
    map: component.map.Id = .town,
    position: zhu.Vector2 = .zero,
    facing: component.actor.Facing = .down,
};

pub const Item = component.item.Stack;

pub const Inventory = struct {
    activeHotbar: usize = 0,
    activePage: usize = 0,
    slots: []const Item = &.{},
    hotbar: []const ?usize = &.{},
};

pub const Product = struct {
    product: component.item.Product,
    health: component.item.Health,
};

pub const Thing = union(enum) {
    gone,
    crop: component.farm.Crop,
    chest: component.item.Chest,
    product: Product,
};

pub const MapTile = struct {
    index: u32 = 0,
    land: ?component.farm.Ground = null,
    thing: ?Thing = null,
};

pub const Map = struct {
    id: component.map.Id = .town,
    day: u32 = 0,
    tiles: []const MapTile = &.{},
};

pub const Record = struct {
    timestamp: i64 = 0,
    clock: Clock = .{},
    player: Player = .{},
    inventory: Inventory = .{},
    maps: []const Map = &.{},
};

var config: Config = .{};
pub var slots: [10]Slot = @splat(.empty);

pub fn init(world: *World) Config {
    config = load(Config, "config.zon", .{});
    slots = load(@TypeOf(slots), "saves/slots.zon", @splat(.empty));
    sync(world, config);
    return config;
}

pub fn update(world: *World, cfg: Config) void {
    if (std.meta.eql(config, cfg)) return;

    sync(world, cfg);
    zhu.window.saveZon("config.zon", cfg) catch |err| {
        std.log.err("save config failed: {}", .{err});
        return;
    };
    config = cfg;
}

fn sync(world: *World, cfg: Config) void {
    world.getPtr(world.entity, Speed).?.value = cfg.speed;
    zhu.audio.musicVolume.store(cfg.music, .release);
    zhu.audio.soundVolume.store(cfg.sound, .release);
}

pub fn read(slot: u8) !zhu.window.Zon(Record) {
    var buffer: [32]u8 = undefined;
    const path = zhu.formatZ(&buffer, "saves/slot{d}.zon", .{slot});
    const record = try zhu.window.readZon(Record, path, .{});
    std.log.info("game loaded: {s}", .{path});
    return record;
}

pub fn write(slot: u8, record: Record) !void {
    var buffer: [32]u8 = undefined;
    const path = zhu.formatZ(&buffer, "saves/slot{d}.zon", .{slot});

    try zhu.window.saveZon(path, record);

    slots[slot] = .{ .valid = .{
        .day = record.clock.day,
        .timestamp = record.timestamp,
    } };
    try zhu.window.saveZon("saves/slots.zon", slots);
    std.log.info("game saved: {s}", .{path});
}

fn load(T: type, path: [:0]const u8, default: T) T {
    var loaded = zhu.window.readZon(T, path, .{}) catch |err| switch (err) {
        error.FileNotFound => return default,
        else => std.debug.panic("load {s} failed: {}", .{ path, err }),
    };
    defer loaded.deinit();

    return loaded.value;
}
