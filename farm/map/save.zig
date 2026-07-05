const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const factory = @import("../factory.zig");
const storage = @import("../storage.zig");
const Land = @import("Land.zig");
const Spatial = @import("Spatial.zig");

const tiled = zhu.extend.tiled;
const World = zhu.ecs.World;
const Entity = zhu.ecs.Entity;
const actor = component.actor;
const render = component.render;
const farm = component.farm;
const item = component.item;
const motion = component.motion;
const Id = component.map.Id;
pub const Object = storage.Object;
const Tile = storage.Tile;
const SaveMap = storage.Map;
pub const Save = storage.MapRecord;

pub const Context = struct {
    world: *World,
    current: Id,
    grid: tiled.Grid,
    land: *Land,
    spatial: *Spatial,
};

var states: std.EnumArray(Id, SaveMap) = .initFill(.{});

pub fn deinit(gpa: zhu.Allocator) void {
    for (std.enums.values(Id)) |id| {
        const entry = states.getPtr(id);
        gpa.free(entry.tiles);
        entry.* = .{};
    }
}

pub fn reset() void {
    for (std.enums.values(Id)) |id| {
        const entry = states.getPtr(id);
        if (entry.tiles.len != 0) @memset(entry.tiles, .{});
        entry.day = 1;
    }
}

pub fn saveCurrent(gpa: zhu.Allocator, ctx: Context, day: u32) void {
    const state = ensure(gpa, ctx.current, ctx.land.tiles.len, day);
    for (ctx.land.tiles, 0..) |tile, index| {
        var saved = &state.tiles[index];
        saved.ground = tile.ground;
        if (objectAt(ctx.world, tile)) |object| {
            saved.object = object;
        } else if (tile.gone == .product) {
            saved.object = .gone;
        } else {
            saved.object = null;
        }
    }
    state.day = day;
}

pub fn capture(gpa: zhu.Allocator) Save {
    var result: Save = .{};

    for (std.enums.values(Id)) |id| {
        const state = states.getPtrConst(id);
        result.maps.set(id, .{
            .day = state.day,
            .tiles = captureTiles(gpa, state),
        });
    }

    return result;
}

pub fn restore(
    gpa: zhu.Allocator,
    maps: []const tiled.Map,
    savedMaps: Save,
    day: u32,
) !void {
    reset();
    for (std.enums.values(Id)) |id| {
        try restoreMap(gpa, maps, id, savedMaps.maps.get(id), day);
    }
}

pub fn restoreCurrent(gpa: zhu.Allocator, ctx: Context, day: u32) void {
    const state = ensure(gpa, ctx.current, ctx.land.tiles.len, day);
    advanceState(state, day);

    for (state.tiles, 0..) |saved, index| {
        const tile = &ctx.land.tiles[index];
        tile.ground = saved.ground;

        const object = saved.object orelse continue;
        restoreObject(ctx, index, object);
    }

    state.day = day;
}

fn ensure(gpa: zhu.Allocator, id: Id, tileCount: usize, day: u32) *SaveMap {
    const entry = states.getPtr(id);
    if (entry.tiles.len != 0) return entry;

    entry.tiles = gpa.alloc(Tile, tileCount);
    for (entry.tiles, 0..) |*tile, index| {
        tile.* = .{ .index = @intCast(index) };
    }
    entry.day = day;
    return entry;
}

fn captureTiles(gpa: zhu.Allocator, state: *const SaveMap) []Tile {
    var list: std.ArrayList(Tile) = .empty;

    if (state.tiles.len == 0) return list.toOwnedSlice(gpa.raw) catch zhu.oom();

    for (state.tiles) |tile| {
        if (tile.ground == null and tile.object == null) continue;
        list.append(gpa.raw, tile) catch zhu.oom();
    }

    return list.toOwnedSlice(gpa.raw) catch zhu.oom();
}

fn restoreMap(
    gpa: zhu.Allocator,
    maps: []const tiled.Map,
    id: Id,
    saved: SaveMap,
    day: u32,
) !void {
    const mapData = &maps[@intFromEnum(id)];
    const tileCount = mapData.grid.count();
    const state = ensure(gpa, id, tileCount, day);

    for (saved.tiles) |tileSave| {
        if (tileSave.index >= state.tiles.len) return error.InvalidSaveTile;

        const index: usize = @intCast(tileSave.index);
        const tile = &state.tiles[index];
        tile.ground = tileSave.ground;
        tile.object = tileSave.object;
    }

    state.day = saved.day;
}

fn objectAt(world: *World, tile: Land.Tile) ?Object {
    const object = tile.object orelse return null;
    return switch (object.kind) {
        .crop => .{ .crop = world.get(object.entity, farm.Crop).? },
        .chest => .{ .chest = world.get(object.entity, item.Chest).? },
        .product => .{ .product = world.get(object.entity, item.Health).? },
    };
}

pub fn restoreObject(ctx: Context, index: usize, data: Object) void {
    switch (data) {
        .gone => clearProductIndex(ctx, index),
        .crop => |crop| {
            const position = ctx.grid.indexToWorld(index);
            const entity = factory.spawnCrop(ctx.world, position, crop.kind);
            ctx.world.getPtr(entity, farm.Crop).?.* = crop;
            refreshCropSprite(ctx.world, entity, crop);
            ctx.land.tiles[index].set(.crop, entity);
        },
        .chest => |saved| {
            const object = ctx.land.tiles[index].object.?;
            std.debug.assert(object.kind == .chest);
            const chest = ctx.world.getPtr(object.entity, item.Chest).?;
            chest.* = saved;
            if (!saved.opened) return;

            const animation = ctx.world.getPtr(
                object.entity,
                actor.Animation,
            ).?;
            const sprite = ctx.world.getPtr(object.entity, render.Sprite).?;
            // 已打开宝箱只需要固定打开帧，后续不再参与动画系统。
            sprite.image = animation.subImageAt(animation.clip.len - 1);
            ctx.world.remove(object.entity, actor.Animation);
            ctx.world.remove(object.entity, motion.Shape);
        },
        .product => |saved| {
            const object = ctx.land.tiles[index].object.?;
            std.debug.assert(object.kind == .product);
            ctx.world.getPtr(object.entity, item.Health).?.* = saved;
        },
    }
}

// 清除地图上的默认产出对象，并记录为 gone，避免后续恢复时重新生成。
pub fn clearProduct(ctx: Context, position: zhu.Vector2) void {
    clearProductIndex(ctx, ctx.grid.worldToIndex(position).?);
}

fn clearProductIndex(ctx: Context, index: usize) void {
    const object = ctx.land.tiles[index].object.?;
    std.debug.assert(object.kind == .product);
    // 对象层产出会注册精确碰撞矩形；tile 层产出只写瓦片阻挡。
    if (ctx.world.get(object.entity, component.map.SolidRange)) |range| {
        ctx.spatial.clearSolidRange(range);
    } else {
        ctx.spatial.clearTileBlock(index);
    }
    ctx.world.destroyEntity(object.entity);
    clearProductTiles(ctx, object.entity);
    ctx.land.tiles[index].gone = .product;
}

// 只清引用，不写 gone；gone 只记录在触发销毁的那一个格子上。
fn clearProductTiles(ctx: Context, entity: zhu.ecs.Entity) void {
    for (ctx.land.tiles) |*tile| {
        if (tile.get(.product) == entity) tile.object = null;
    }
}

pub fn advanceState(state: *SaveMap, day: u32) void {
    if (day <= state.day) return;

    const days = day - state.day;
    for (0..days) |_| advanceStateOneDay(state);
    state.day = day;
}

fn advanceStateOneDay(state: *SaveMap) void {
    for (state.tiles) |*tile| {
        const watered = tile.ground == .wet;
        // 浇水只影响当天，跨天后湿地统一变回干地。
        if (tile.ground == .wet) tile.ground = .dry;

        const object = tile.object orelse continue;
        switch (object) {
            .crop => |cropState| {
                var crop = cropState;
                _ = advanceCropOneDay(&crop, watered);
                tile.object = .{ .crop = crop };
            },
            .gone, .chest, .product => {},
        }
    }
}

pub fn advanceCropOneDay(crop: *farm.Crop, watered: bool) bool {
    if (crop.stage == .mature) return false;

    crop.next -= if (watered) 2 else 1;
    crop.timer = 0;
    if (crop.next > 0) return false;

    crop.stage = zhu.enums.next(crop.stage);
    crop.next = factory.cropStage(crop.kind, crop.stage).duration;
    return true;
}

pub fn refreshCropSprite(world: *World, entity: Entity, crop: farm.Crop) void {
    const cfg = factory.cropStage(crop.kind, crop.stage);
    world.getPtr(entity, render.Sprite).?.* = .{
        .image = factory.resolveImage(cfg.sprite),
        .offset = cfg.sprite.offset,
    };
    if (crop.stage == .seed) return;
    world.getPtr(entity, render.Render).?.layer = .actor;
}
