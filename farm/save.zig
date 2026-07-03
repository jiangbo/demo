const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const inventory = @import("inventory.zig");
const map = @import("map.zig");
const Clock = @import("global/Clock.zig");
const Maps = @import("state.zig").Maps;

const World = zhu.ecs.World;
const Actor = component.actor.Actor;
const Busy = component.actor.Busy;
const Player = component.actor.Player;
const Position = component.Position;
const Target = component.ui.Target;
const Velocity = component.motion.Velocity;

pub const slotCount: usize = 10;
const maxSaveSize = 128 * 1024;

pub const Config = struct {
    speed: f32 = 1,
    music: f32 = 1,
    sound: f32 = 1,
};

pub const SlotSummary = struct {
    day: u32 = 0,
    timestamp: i64 = 0,
};

pub const Slot = union(enum) {
    empty,
    invalid,
    valid: SlotSummary,
};

pub var slots: [slotCount]Slot = @splat(.empty);
var allocator: std.mem.Allocator = undefined;
var savedConfig: Config = .{};

const TimeSave = struct {
    paused: bool = false,
    day: u32 = 1,
    hour: u8 = 6,
    minute: f32 = 0,
    period: component.time.Period = .dawn,
};

const PlayerSave = struct {
    map: component.map.Id = .town,
    position: zhu.Vector2 = .zero,
    facing: component.actor.Facing = .down,
};

const TileSave = struct {
    index: u32 = 0,
    land: ?component.farm.Ground = null,
    thing: ?Maps.Thing = null,
};

const MapSave = struct {
    id: component.map.Id = .town,
    day: u32 = 0,
    tiles: []const TileSave = &.{},
};

const SaveData = struct {
    timestamp: i64 = 0,
    time: TimeSave = .{},
    player: PlayerSave = .{},
    inventory: inventory.Save = .{},
    maps: []const MapSave = &.{},
};

pub fn slotPath(slot: u8, buffer: []u8) ![:0]const u8 {
    if (slot >= slotCount) return error.InvalidSaveSlot;
    return try std.fmt.bufPrintZ(buffer, "saves/slot{d}.zon", .{slot});
}

pub fn init(allocator_: zhu.Allocator) Config {
    allocator = allocator_.raw;
    const config = loadConfig();
    savedConfig = config;
    applyConfig(config);

    for (&slots, 0..) |*state, index| {
        const slot: u8 = @intCast(index);
        const summary = readSlotSummary(slot) catch |err| {
            std.log.warn("slot {} summary failed: {}", .{ index, err });
            state.* = .invalid;
            continue;
        };
        state.* = if (summary) |value| .{ .valid = value } else .empty;
    }
    return config;
}

pub fn update(config: Config) void {
    if (std.meta.eql(savedConfig, config)) return;

    applyConfig(config);
    saveConfig(config);
    savedConfig = config;
}

pub fn saveSlot(world: *World, maps: *Maps, slot: u8) bool {
    saveSlotInner(world, maps, slot) catch |err| {
        std.log.err("save slot {} failed: {}", .{ slot, err });
        return false;
    };
    return true;
}

pub fn loadSlot(world: *World, maps: *Maps, slot: u8) bool {
    loadSlotInner(world, maps, slot) catch |err| {
        std.log.err("load slot {} failed: {}", .{ slot, err });
        return false;
    };
    return true;
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
    var buffer: [256]u8 = undefined;
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

fn saveSlotInner(world: *World, maps: *Maps, slot: u8) !void {
    const clock = world.getPtr(world.entity, Clock).?;
    var pathBuffer: [32]u8 = undefined;
    const path = try slotPath(slot, &pathBuffer);

    map.saveState(world, maps, clock.day);
    const data = try capture(world, clock, maps);
    defer freeCaptured(data);

    const buffer = zhu.assets.oomAlloc(u8, maxSaveSize);
    defer zhu.assets.free(buffer);

    var writer = std.Io.Writer.fixed(buffer);
    try std.zon.stringify.serialize(data, .{}, &writer);
    try zhu.window.saveAll(path, buffer[0..writer.end]);

    slots[slot] = .{ .valid = .{
        .day = data.time.day,
        .timestamp = data.timestamp,
    } };
    std.log.info("game saved: {s}", .{path});
}

fn loadSlotInner(world: *World, maps: *Maps, slot: u8) !void {
    const clock = world.getPtr(world.entity, Clock).?;
    var pathBuffer: [32]u8 = undefined;
    const path = try slotPath(slot, &pathBuffer);

    var save = try zhu.window.readZon(SaveData, path, .{});
    defer save.deinit();

    try apply(world, clock, maps, save.value);
    std.log.info("game loaded: {s}", .{path});
}

pub fn readSlotSummary(slot: u8) !?SlotSummary {
    var pathBuffer: [32]u8 = undefined;
    const path = try slotPath(slot, &pathBuffer);

    const source = zhu.window.readAll(allocator, path) catch |err|
        switch (err) {
            error.FileNotFound => return null,
            else => return err,
        };
    defer allocator.free(source);

    return try parseSlotSummary(source);
}

pub fn parseSlotSummary(content: []const u8) !SlotSummary {
    // 槽位列表只需要两个字段，不为摘要解析完整大存档。
    const timeIndex = std.mem.indexOf(u8, content, ".time") orelse {
        return error.InvalidSaveSummary;
    };

    return .{
        .day = try parseFieldInt(u32, content[timeIndex..], ".day"),
        .timestamp = try parseFieldInt(i64, content, ".timestamp"),
    };
}

fn parseFieldInt(T: type, content: []const u8, field: []const u8) !T {
    const fieldIndex = std.mem.indexOf(u8, content, field) orelse {
        return error.InvalidSaveSummary;
    };

    var index = fieldIndex + field.len;
    while (index < content.len and content[index] != '=') : (index += 1) {}
    if (index == content.len) return error.InvalidSaveSummary;

    index += 1;
    while (index < content.len and isSpace(content[index])) : (index += 1) {}
    const start = index;

    if (index < content.len and content[index] == '-') index += 1;
    while (index < content.len and std.ascii.isDigit(content[index])) {
        index += 1;
    }
    if (start == index) return error.InvalidSaveSummary;

    return try std.fmt.parseInt(T, content[start..index], 10);
}

fn isSpace(char: u8) bool {
    return switch (char) {
        ' ', '\n', '\r', '\t' => true,
        else => false,
    };
}

fn capture(world: *World, clock: *const Clock, maps: *const Maps) !SaveData {
    const player = world.getIdentity(Player) orelse return error.MissingPlayer;
    const position = world.get(player, Position) orelse {
        return error.MissingPlayerPosition;
    };
    const actor = world.get(player, Actor) orelse Actor{};

    return .{
        .timestamp = zhu.window.timestamp().toSeconds(),
        .time = .{
            .paused = clock.paused,
            .day = clock.day,
            .hour = clock.hour,
            .minute = clock.minute,
            .period = clock.period,
        },
        .player = .{
            .map = map.current,
            .position = position,
            .facing = actor.facing,
        },
        .inventory = inventory.capture(),
        .maps = try captureMaps(maps),
    };
}

fn freeCaptured(data: SaveData) void {
    for (data.maps) |saved| allocator.free(saved.tiles);
    allocator.free(data.maps);
}

fn captureMaps(maps: *const Maps) ![]const MapSave {
    const ids = std.enums.values(component.map.Id);
    var result = try std.ArrayList(MapSave).initCapacity(
        allocator,
        ids.len,
    );
    errdefer {
        for (result.items) |saved| allocator.free(saved.tiles);
        result.deinit(allocator);
    }

    for (ids) |id| {
        const state = maps.items.getPtrConst(id);
        try result.append(allocator, .{
            .id = id,
            .day = state.day,
            .tiles = try captureTiles(state),
        });
    }

    return try result.toOwnedSlice(allocator);
}

fn captureTiles(state: *const Maps.Entry) ![]const TileSave {
    var list: std.ArrayList(TileSave) = .empty;
    errdefer list.deinit(allocator);

    if (state.tiles.len == 0) return try list.toOwnedSlice(allocator);

    for (state.tiles, 0..) |tile, index| {
        if (tile.ground == null and tile.thing == null) continue;

        try list.append(allocator, .{
            .index = @intCast(index),
            .land = tile.ground,
            .thing = tile.thing,
        });
    }

    return try list.toOwnedSlice(allocator);
}

fn apply(world: *World, clock: *Clock, maps: *Maps, data: SaveData) !void {
    clock.paused = data.time.paused;
    clock.day = data.time.day;
    clock.hour = data.time.hour;
    clock.minute = data.time.minute;
    clock.period = data.time.period;

    map.exit(world, maps, clock.day);
    maps.reset();
    restoreMaps(data, maps, clock.day);

    world.resetKeep(.{Clock});
    world.entity = world.createEntity();
    map.enter(world, maps, data.player.map, -1, clock.day);
    restorePlayer(world, data.player);
    inventory.restore(data.inventory);
}

fn restoreMaps(data: SaveData, maps: *Maps, day: u32) void {
    for (data.maps) |saved| restoreMap(saved, maps, day);
}

fn restoreMap(data: MapSave, maps: *Maps, day: u32) void {
    const mapData = &map.maps[@intFromEnum(data.id)];
    const tileCount = mapData.grid.count();
    const state = maps.ensure(data.id, tileCount, day);

    for (data.tiles) |tileSave| {
        if (tileSave.index >= state.tiles.len) continue;

        const index: usize = @intCast(tileSave.index);
        const tile = &state.tiles[index];
        tile.ground = tileSave.land;
        tile.thing = tileSave.thing;
    }

    state.day = data.day;
}

fn restorePlayer(world: *World, data: PlayerSave) void {
    const player = world.getIdentity(Player) orelse return;
    if (world.getPtr(player, Position)) |position| {
        position.* = data.position;
    }
    if (world.getPtr(player, Velocity)) |velocity| {
        velocity.value = .zero;
    }
    if (world.getPtr(player, Target)) |target| {
        target.active = false;
    }
    if (world.getPtr(player, Actor)) |actor| {
        actor.action = .idle;
        actor.facing = data.facing;
    }
    world.remove(player, Busy);
    zhu.camera.directFollow(data.position);
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

test "parseSlotSummary 会读取天数和时间戳" {
    const content =
        \\.{
        \\    .timestamp = 42,
        \\    .time = .{
        \\        .day = 7,
        \\    },
        \\}
    ;

    const summary = try parseSlotSummary(content);

    try std.testing.expectEqual(7, summary.day);
    try std.testing.expectEqual(42, summary.timestamp);
}

test "parseSlotSummary 会忽略完整存档的其它字段" {
    const content =
        \\.{
        \\    .timestamp = 42,
        \\    .time = .{
        \\        .day = 7,
        \\    },
        \\    .player = .{},
        \\    .inventory = .{},
        \\    .maps = .{},
        \\}
    ;

    const summary = try parseSlotSummary(content);

    try std.testing.expectEqual(7, summary.day);
    try std.testing.expectEqual(42, summary.timestamp);
}

test "inventory.restore 会恢复库存槽和快捷栏" {
    inventory.reset();
    defer inventory.reset();

    const stacks = [_]inventory.Stack{
        .{ .item = .strawberrySeed, .count = 7 },
    };
    var data = inventory.Save{
        .activeHotbar = 3,
        .activePage = 1,
        .slots = &stacks,
    };
    data.hotbar[3] = 0;

    inventory.restore(data);

    try std.testing.expectEqual(
        component.item.ItemEnum.strawberrySeed,
        inventory.activeItem().?,
    );
    const index = inventory.bar.refs[inventory.bar.active].?;
    try std.testing.expectEqual(7, inventory.store.stacks[index].count);
    try std.testing.expectEqual(0, inventory.bar.refs[3].?);
    try std.testing.expectEqual(3, inventory.bar.active);
    try std.testing.expectEqual(1, inventory.bag.activePage);
}
