const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const Clock = @import("global/Clock.zig");

pub const slotCount: usize = 10;
const hotbarCount = 10;
const maxSaveSize = 128 * 1024;

pub const SlotSummary = struct {
    day: u32 = 0,
    timestamp: i64 = 0,
};

pub const Slot = union(enum) {
    empty,
    invalid,
    valid: SlotSummary,
};

pub const Config = struct {
    speed: f32 = 1,
    music: f32 = 1,
    sound: f32 = 1,
    slots: [slotCount]Slot = @splat(.empty),
};

pub const Player = struct {
    map: component.map.Id = .town,
    position: zhu.Vector2 = .zero,
    facing: component.actor.Facing = .down,
};

pub const Item = struct {
    item: component.item.ItemEnum = .hoe,
    count: u32 = 0,
};

pub const Inventory = struct {
    activeHotbar: usize = 0,
    activePage: usize = 0,
    slots: []const Item = &.{},
    hotbar: [hotbarCount]?usize = @splat(null),
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
    time: Clock = .{},
    player: Player = .{},
    inventory: Inventory = .{},
    maps: []const Map = &.{},
};

var savedConfig: Config = .{};

pub fn init() Config {
    const config = loadConfig();
    savedConfig = config;
    applyConfig(config);
    return config;
}

pub fn update(config: Config) void {
    if (std.meta.eql(savedConfig, config)) return;

    applyConfig(config);
    saveConfig(config);
    savedConfig = config;
}

pub fn slotPath(slot: u8, buffer: []u8) ![:0]const u8 {
    if (slot >= slotCount) return error.InvalidSaveSlot;
    return try std.fmt.bufPrintZ(buffer, "saves/slot{d}.zon", .{slot});
}

pub fn read(slot: u8) !zhu.window.Zon(Record) {
    var pathBuffer: [32]u8 = undefined;
    const path = try slotPath(slot, &pathBuffer);
    const record = try zhu.window.readZon(Record, path, .{});
    std.log.info("game loaded: {s}", .{path});
    return record;
}

pub fn write(slot: u8, record: Record, config: *Config) !void {
    var pathBuffer: [32]u8 = undefined;
    const path = try slotPath(slot, &pathBuffer);

    const buffer = zhu.assets.oomAlloc(u8, maxSaveSize);
    defer zhu.assets.free(buffer);

    var writer = std.Io.Writer.fixed(buffer);
    try std.zon.stringify.serialize(record, .{}, &writer);
    try zhu.window.saveAll(path, buffer[0..writer.end]);

    config.slots[slot] = .{ .valid = .{
        .day = record.time.day,
        .timestamp = record.timestamp,
    } };
    saveConfig(config.*);
    savedConfig = config.*;
    std.log.info("game saved: {s}", .{path});
}

fn loadConfig() Config {
    var loaded = zhu.window.readZon(Config, "config.zon", .{}) catch |err|
        switch (err) {
            error.FileNotFound => return .{},
            else => std.debug.panic("load config failed: {}", .{err}),
        };
    defer loaded.deinit();

    return loaded.value;
}

fn saveConfig(config: Config) void {
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    std.zon.stringify.serialize(config, .{}, &writer) catch |err| {
        std.debug.panic("save config failed: {}", .{err});
    };
    zhu.window.saveAll("config.zon", buffer[0..writer.end]) catch |err| {
        std.debug.panic("save config failed: {}", .{err});
    };
}

fn applyConfig(config: Config) void {
    zhu.audio.musicVolume.store(config.music, .release);
    zhu.audio.soundVolume.store(config.sound, .release);
}

test "slotPath 会生成存档槽路径" {
    var buffer: [32]u8 = undefined;
    const path = try slotPath(3, &buffer);
    const invalidSlot: u8 = slotCount;

    try std.testing.expectEqualStrings("saves/slot3.zon", path);
    try std.testing.expectError(
        error.InvalidSaveSlot,
        slotPath(invalidSlot, &buffer),
    );
}
