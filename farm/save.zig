const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const context = @import("context.zig");
const map = @import("map.zig");
const toolbar = @import("ui/toolbar.zig");

const World = zhu.ecs.World;
const Actor = component.actor.Actor;
const Player = component.actor.Player;
const Position = component.Position;
const Target = component.ui.Target;
const Velocity = component.motion.Velocity;

pub const slotCount: usize = 10;
const schemaVersion = 1;
const maxSaveSize = 128 * 1024;

pub const SlotSummary = struct {
    day: u32 = 0,
    timestamp: i64 = 0,
};

const TimeSave = struct {
    paused: bool = false,
    scale: f32 = 1,
    day: u32 = 1,
    hour: u8 = 6,
    minute: f32 = 0,
    period: context.clock.Period = .dawn,
};

const PlayerSave = struct {
    map: component.map.Id = .town,
    position: zhu.Vector2 = .zero,
    facing: component.actor.Facing = .down,
};

const ToolbarSlotSave = struct {
    type: component.item.ItemEnum = .hoe,
    count: u32 = 0,
};

const ToolbarSave = struct {
    slotIndex: usize = 0,
    slots: [toolbar.slots.len]ToolbarSlotSave = @splat(.{}),
};

const TileSave = struct {
    index: u32 = 0,
    land: ?component.farm.Ground = null,
    crop: ?component.farm.Crop = null,
};

const MapSave = struct {
    id: component.map.Id = .town,
    day: u32 = 0,
    tiles: []const TileSave = &.{},
};

const SaveData = struct {
    schemaVersion: u32 = schemaVersion,
    timestamp: i64 = 0,
    time: TimeSave = .{},
    player: PlayerSave = .{},
    toolbar: ToolbarSave = .{},
    maps: []const MapSave = &.{},
};

const SummaryTime = struct {
    day: u32 = 0,
};

const SummaryData = struct {
    schemaVersion: u32 = 0,
    timestamp: i64 = 0,
    time: SummaryTime = .{},
};

pub fn slotPath(slot: usize, buffer: []u8) ![:0]const u8 {
    if (slot >= slotCount) return error.InvalidSaveSlot;
    return try std.fmt.bufPrintZ(buffer, "saves/slot{d}.zon", .{slot});
}

pub fn saveSlot(world: *World, slot: usize) !void {
    var pathBuffer: [32]u8 = undefined;
    const path = try slotPath(slot, &pathBuffer);

    map.saveState(world);
    const data = try capture(world);
    defer freeCaptured(data);

    const buffer = zhu.assets.oomAlloc(u8, maxSaveSize);
    defer zhu.assets.free(buffer);

    var writer = std.Io.Writer.fixed(buffer);
    try std.zon.stringify.serialize(data, .{}, &writer);
    try zhu.window.saveAll(path, buffer[0..writer.end]);

    std.log.info("game saved: {s}", .{path});
}

pub fn loadSlot(world: *World, slot: usize) !void {
    var pathBuffer: [32]u8 = undefined;
    const path = try slotPath(slot, &pathBuffer);

    const content = try zhu.window.readAll(path);
    defer zhu.assets.free(content);

    const terminated = try std.fmt.allocPrintSentinel(
        zhu.assets.allocator,
        "{s}",
        .{content},
        0,
    );
    defer zhu.assets.free(terminated);

    const data = try std.zon.parse.fromSlice(
        SaveData,
        zhu.assets.allocator,
        terminated,
        null,
        .{},
    );
    defer std.zon.parse.free(zhu.assets.allocator, data);

    try apply(world, data);
    std.log.info("game loaded: {s}", .{path});
}

pub fn readSlotSummary(slot: usize) !?SlotSummary {
    var pathBuffer: [32]u8 = undefined;
    const path = try slotPath(slot, &pathBuffer);

    const content = zhu.window.readAll(path) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer zhu.assets.free(content);

    return try parseSlotSummary(content, zhu.assets.allocator);
}

pub fn parseSlotSummary(
    content: []const u8,
    allocator: std.mem.Allocator,
) !SlotSummary {
    const terminated = try std.fmt.allocPrintSentinel(
        allocator,
        "{s}",
        .{content},
        0,
    );
    defer allocator.free(terminated);

    const data = try std.zon.parse.fromSlice(
        SummaryData,
        allocator,
        terminated,
        null,
        .{},
    );
    defer std.zon.parse.free(allocator, data);

    if (data.schemaVersion == 0) return error.MissingSaveVersion;
    if (data.schemaVersion > schemaVersion) return error.UnsupportedSaveVersion;

    return .{
        .day = data.time.day,
        .timestamp = data.timestamp,
    };
}

fn capture(world: *World) !SaveData {
    const player = world.getIdentity(Player) orelse return error.MissingPlayer;
    const position = world.get(player, Position) orelse {
        return error.MissingPlayerPosition;
    };
    const actor = world.get(player, Actor) orelse Actor{};

    return .{
        .timestamp = std.time.timestamp(),
        .time = .{
            .paused = context.clock.paused,
            .scale = context.clock.speed,
            .day = context.clock.day,
            .hour = context.clock.hour,
            .minute = context.clock.minute,
            .period = context.clock.period,
        },
        .player = .{
            .map = map.current,
            .position = position,
            .facing = actor.facing,
        },
        .toolbar = captureToolbar(),
        .maps = try captureMaps(),
    };
}

fn freeCaptured(data: SaveData) void {
    for (data.maps) |saved| zhu.assets.free(saved.tiles);
    zhu.assets.free(data.maps);
}

fn captureToolbar() ToolbarSave {
    var result = ToolbarSave{ .slotIndex = toolbar.slotIndex };
    for (toolbar.slots, 0..) |slot, index| {
        result.slots[index] = .{
            .type = slot.type,
            .count = slot.count,
        };
    }
    return result;
}

fn captureMaps() ![]const MapSave {
    const ids = std.enums.values(component.map.Id);
    var result = try std.ArrayList(MapSave).initCapacity(
        zhu.assets.allocator,
        ids.len,
    );
    errdefer {
        for (result.items) |saved| zhu.assets.free(saved.tiles);
        result.deinit(zhu.assets.allocator);
    }

    for (ids) |id| {
        const state = context.map.states.getPtr(id);
        try result.append(zhu.assets.allocator, .{
            .id = id,
            .day = state.day,
            .tiles = try captureTiles(state),
        });
    }

    return try result.toOwnedSlice(zhu.assets.allocator);
}

fn captureTiles(state: *const context.map.State) ![]const TileSave {
    var list: std.ArrayList(TileSave) = .empty;
    errdefer list.deinit(zhu.assets.allocator);

    if (!state.initialized) return try list.toOwnedSlice(zhu.assets.allocator);

    for (state.tiles, 0..) |tile, index| {
        if (tile.ground == null and tile.crop == null) continue;

        try list.append(zhu.assets.allocator, .{
            .index = @intCast(index),
            .land = tile.ground,
            .crop = if (tile.crop) |crop| .{
                .stage = crop.stage,
                .kind = crop.kind,
                .timer = crop.timer,
                .next = crop.next,
                .watered = crop.watered,
            } else null,
        });
    }

    return try list.toOwnedSlice(zhu.assets.allocator);
}

fn apply(world: *World, data: SaveData) !void {
    if (data.schemaVersion > schemaVersion) return error.UnsupportedSaveVersion;

    context.clock.paused = data.time.paused;
    context.clock.speed = data.time.scale;
    context.clock.day = data.time.day;
    context.clock.hour = data.time.hour;
    context.clock.minute = data.time.minute;
    context.clock.period = data.time.period;

    map.exit(world);
    context.map.resetStates();
    restoreMaps(data);

    _ = map.enter(world, data.player.map, -1);
    restorePlayer(world, data.player);
    restoreToolbar(data.toolbar);
}

fn restoreMaps(data: SaveData) void {
    for (data.maps) |saved| restoreMap(saved);
}

fn restoreMap(data: MapSave) void {
    const mapData = &map.maps[@intFromEnum(data.id)];
    const tileCount = mapData.width * mapData.height;
    const state = context.map.ensureState(data.id, tileCount);

    for (data.tiles) |tileSave| {
        if (tileSave.index >= state.tiles.len) continue;

        const index: usize = @intCast(tileSave.index);
        const tile = &state.tiles[index];
        tile.ground = tileSave.land;

        if (tileSave.crop) |crop| {
            tile.crop = .{
                .stage = crop.stage,
                .kind = crop.kind,
                .timer = crop.timer,
                .next = crop.next,
                .watered = crop.watered,
            };
        } else {
            tile.crop = null;
        }
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
    zhu.camera.directFollow(data.position);
}

fn restoreToolbar(data: ToolbarSave) void {
    for (&toolbar.slots, 0..) |*slot, index| {
        slot.* = if (index < data.slots.len) .{
            .type = data.slots[index].type,
            .count = data.slots[index].count,
        } else .{ .type = .hoe, .count = 0 };
    }
    toolbar.slotIndex = @min(data.slotIndex, toolbar.slots.len - 1);
}

test "slotPath builds save slot path" {
    var buffer: [32]u8 = undefined;
    const path = try slotPath(3, &buffer);

    try std.testing.expectEqualStrings("saves/slot3.zon", path);
    try std.testing.expectError(error.InvalidSaveSlot, slotPath(slotCount, &buffer));
}

test "parseSlotSummary reads day and timestamp" {
    const content =
        \\.{
        \\    .schemaVersion = 1,
        \\    .timestamp = 42,
        \\    .time = .{
        \\        .day = 7,
        \\    },
        \\}
    ;

    const summary = try parseSlotSummary(content, std.testing.allocator);

    try std.testing.expectEqual(7, summary.day);
    try std.testing.expectEqual(42, summary.timestamp);
}

test "parseSlotSummary rejects future save version" {
    const content =
        \\.{
        \\    .schemaVersion = 2,
        \\    .time = .{ .day = 1 },
        \\}
    ;

    try std.testing.expectError(
        error.UnsupportedSaveVersion,
        parseSlotSummary(content, std.testing.allocator),
    );
}

test "restoreToolbar restores slots and clamps index" {
    const oldSlots = toolbar.slots;
    const oldIndex = toolbar.slotIndex;
    defer {
        toolbar.slots = oldSlots;
        toolbar.slotIndex = oldIndex;
    }

    toolbar.slots = @splat(.{ .type = .hoe, .count = 0 });
    toolbar.slotIndex = 0;

    var data = ToolbarSave{ .slotIndex = 999 };
    data.slots[0] = .{ .type = .strawberrySeed, .count = 7 };

    restoreToolbar(data);

    try std.testing.expectEqual(component.item.ItemEnum.strawberrySeed, toolbar.slots[0].type);
    try std.testing.expectEqual(7, toolbar.slots[0].count);
    try std.testing.expectEqual(toolbar.slots.len - 1, toolbar.slotIndex);
}
