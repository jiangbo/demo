const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const context = @import("context.zig");
const factory = @import("factory.zig");
const map = @import("map.zig");
const prefab = @import("prefab.zig");
const toolbar = @import("ui/toolbar.zig");

const World = zhu.ecs.World;
const Actor = component.actor.Actor;
const Crop = component.farm.Crop;
const Player = component.actor.Player;
const Position = component.Position;
const Sprite = component.render.Sprite;
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
    period: context.time.Period = .dawn,
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

const LandSave = enum { dry, wet };

const CropSave = struct {
    stage: component.farm.GrowthEnum = .seed,
    timer: f32 = 0,
    next: f32 = 0,
    watered: bool = false,
};

const TileSave = struct {
    index: u32 = 0,
    land: ?LandSave = null,
    crop: ?CropSave = null,
};

const MapSave = struct {
    id: component.map.Id = .town,
    tiles: []const TileSave = &.{},
};

const SaveData = struct {
    schemaVersion: u32 = schemaVersion,
    timestamp: i64 = 0,
    time: TimeSave = .{},
    player: PlayerSave = .{},
    toolbar: ToolbarSave = .{},
    map: MapSave = .{},
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
        .{ .ignore_unknown_fields = true },
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
        .{ .ignore_unknown_fields = true },
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
            .paused = context.time.paused,
            .scale = context.time.scale,
            .day = context.time.day,
            .hour = context.time.hour,
            .minute = context.time.minute,
            .period = context.time.period,
        },
        .player = .{
            .map = map.current,
            .position = position,
            .facing = actor.facing,
        },
        .toolbar = captureToolbar(),
        .map = .{
            .id = map.current,
            .tiles = try captureTiles(world),
        },
    };
}

fn freeCaptured(data: SaveData) void {
    zhu.assets.free(data.map.tiles);
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

fn captureTiles(world: *World) ![]const TileSave {
    var list: std.ArrayList(TileSave) = .empty;
    errdefer list.deinit(zhu.assets.allocator);

    for (map.land.tiles, 0..) |tile, index| {
        if (tile.land == null and tile.crop == null) continue;

        var cropSave: ?CropSave = null;
        if (tile.crop) |entity| {
            if (world.get(entity, Crop)) |crop| {
                cropSave = .{
                    .stage = crop.stage,
                    .timer = crop.timer,
                    .next = crop.next,
                    .watered = crop.watered,
                };
            }
        }

        try list.append(zhu.assets.allocator, .{
            .index = @intCast(index),
            .land = if (tile.land) |land| switch (land) {
                .dry => .dry,
                .wet => .wet,
            } else null,
            .crop = cropSave,
        });
    }

    return try list.toOwnedSlice(zhu.assets.allocator);
}

fn apply(world: *World, data: SaveData) !void {
    if (data.schemaVersion > schemaVersion) return error.UnsupportedSaveVersion;

    context.time.paused = data.time.paused;
    context.time.scale = data.time.scale;
    context.time.day = data.time.day;
    context.time.hour = data.time.hour;
    context.time.minute = data.time.minute;
    context.time.period = data.time.period;

    map.exit(world);
    _ = map.enter(world, data.player.map, -1);
    restoreTiles(world, data.map);
    restorePlayer(world, data.player);
    restoreToolbar(data.toolbar);
}

fn restoreTiles(world: *World, data: MapSave) void {
    if (data.id != map.current) return;

    for (data.tiles) |tileSave| {
        if (tileSave.index >= map.land.tiles.len) continue;

        const index: usize = @intCast(tileSave.index);
        const tile = &map.land.tiles[index];
        tile.land = if (tileSave.land) |land| switch (land) {
            .dry => .dry,
            .wet => .wet,
        } else null;

        if (tileSave.crop) |crop| {
            const position = map.data.tileIndexToWorld(index);
            const entity = factory.spawnCrop(world, position);
            world.getPtr(entity, Crop).?.* = .{
                .stage = crop.stage,
                .timer = crop.timer,
                .next = crop.next,
                .watered = crop.watered,
            };
            updateCropSprite(world, entity, crop.stage);
            tile.crop = entity;
        }
    }
}

fn updateCropSprite(
    world: *World,
    entity: zhu.ecs.Entity,
    stage: component.farm.GrowthEnum,
) void {
    const config = prefab.farm.crop.stages[@intFromEnum(stage)];
    world.getPtr(entity, Sprite).?.* = .{
        .image = prefab.resolveImage(config.sprite),
        .offset = config.sprite.offset,
    };
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
        \\        .paused = false,
        \\        .scale = 1,
        \\        .day = 7,
        \\        .hour = 6,
        \\    },
        \\    .player = .{},
        \\    .toolbar = .{},
        \\    .map = .{},
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
    data.slots[0] = .{ .type = .seed, .count = 7 };

    restoreToolbar(data);

    try std.testing.expectEqual(component.item.ItemEnum.seed, toolbar.slots[0].type);
    try std.testing.expectEqual(7, toolbar.slots[0].count);
    try std.testing.expectEqual(toolbar.slots.len - 1, toolbar.slotIndex);
}
