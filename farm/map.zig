const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const factory = @import("factory.zig");
const loader = @import("map/loader.zig");
const Spatial = @import("map/Spatial.zig");
const Land = @import("map/Land.zig");
const Maps = @import("state.zig").Maps;

const tiled = zhu.extend.tiled;
const World = zhu.ecs.World;
const Entity = zhu.ecs.Entity;
const actor = component.actor;
const render = component.render;
const farm = component.farm;
const item = component.item;
const motion = component.motion;
const Position = component.Position;
pub const Id = component.map.Id;
pub const StartOffset = component.map.StartOffset;
pub const Hit = component.map.Hit;
const Trigger = component.map.Trigger;
const Thing = Maps.Thing;

pub const maps = tiled.bind(@import("zon/map/tileSet.zon"), &.{
    @import("zon/map/school.zon"),
    @import("zon/map/town.zon"),
    @import("zon/map/exterior.zon"),
    @import("zon/map/interior.zon"),
});

const triggerOffset = 8;

pub var current: Id = .school;
pub var grid: tiled.Grid = maps[0].grid;
var vertexes: std.ArrayList(zhu.batch.Vertex) = .empty;
var frontLayerStart: usize = 0;
var mapImage: zhu.Image = undefined;
var dryLandImage: zhu.Image = undefined;
var wetLandImage: zhu.Image = undefined;
var gpa: zhu.Allocator = undefined;
var land: Land = .{};
var spatial: Spatial = .{};

pub fn isOutdoor(id: Id) bool {
    // 硬编码室内外规则。如需扩展可改为从 ZON 配置读取。
    return switch (id) {
        .town, .exterior => true,
        .school, .interior => false,
    };
}

pub fn init(gpa_: zhu.Allocator) void {
    gpa = gpa_;
    mapImage = zhu.getImage("circle.png").?;
    const landImage = zhu.getImage(
        "farm-rpg/Farm/Tileset/Modular/Tilled Soil and wet soil.png",
    ).?;
    dryLandImage = landImage.sub(.init(.xy(0, 48), .xy(16, 16)));
    wetLandImage = landImage.sub(.init(.xy(192, 48), .xy(16, 16)));
}

pub fn deinit() void {
    vertexes.clearAndFree(gpa.raw);
}

pub fn enter(
    world: *World,
    savedMaps: *Maps,
    id: Id,
    targetId: i32,
    day: u32,
) void {
    current = id;
    load(gpa, world, maps[@intFromEnum(id)]);
    restoreState(world, savedMaps, day);

    var spawn: ?zhu.Vector2 = null;
    var query = world.query(.{Trigger});
    while (query.next()) |entity| {
        const trigger = query.get(entity, Trigger);
        if (trigger.selfId == targetId) {
            spawn = triggerSpawnPosition(trigger);
            break;
        }
    }

    zhu.camera.bound = grid.size();
    const position = spawn orelse zhu.Vector2.xy(311, 168);
    factory.spawnPlayer(world, position);
    zhu.camera.directFollow(position);
}

pub fn update(world: *World) void {
    for (world.getEvent(component.event.DayChanged)) |_| {
        for (land.tiles) |*tile| {
            const watered = tile.ground == .wet;
            // 当前地图和离线地图一致：每天结束湿地变干。
            if (tile.ground == .wet) tile.ground = .dry;

            const entity = tile.get(.crop) orelse continue;
            const crop = world.getPtr(entity, farm.Crop).?;
            if (advanceCropOneDay(crop, watered)) {
                refreshCropSprite(world, entity, crop.*);
            }
            crop.watered = false;
        }
    }
}

pub fn exit(world: *World, savedMaps: *Maps, day: u32) void {
    saveState(world, savedMaps, day);
    unload();
}

pub fn load(gpa_: zhu.Allocator, world: *World, mapData: tiled.Map) void {
    gpa = gpa_;
    grid = mapData.grid;
    zhu.camera.bound = grid.size();

    const loaded = loader.load(gpa, world, mapData);
    land = loaded.land;
    spatial = loaded.spatial;
    vertexes = loaded.vertexes;
    frontLayerStart = loaded.frontLayerStart;
}

pub fn unload() void {
    land.deinit(gpa);
    spatial.deinit(gpa);
    frontLayerStart = 0;
    vertexes.clearAndFree(gpa.raw);
}

pub fn saveState(world: *World, savedMaps: *Maps, day: u32) void {
    if (land.tiles.len == 0) return;

    const state = savedMaps.ensure(current, land.tiles.len, day);
    for (land.tiles, 0..) |tile, index| {
        var saved = &state.tiles[index];
        saved.ground = tile.ground;
        if (thingAt(world, tile)) |thing| {
            saved.thing = thing;
        } else if (tile.gone == .product) {
            saved.thing = .gone;
        } else {
            saved.thing = null;
        }
    }
    state.day = day;
}

pub fn hoe(position: zhu.Vector2) bool {
    if (!spatial.canHoeTile(position)) return false;
    return land.hoe(position);
}

pub fn canPlant(position: zhu.Vector2) bool {
    return land.canPlant(position);
}

pub fn water(position: zhu.Vector2) bool {
    return land.water(position);
}

pub fn getTile(position: zhu.Vector2) ?*Land.Tile {
    return land.getTile(position);
}

pub fn hasAnyBlockAt(position: zhu.Vector2) bool {
    return Spatial.hasAnyBlock(spatial.marksAt(position));
}

pub fn canMove(world: *World, entity: zhu.ecs.Entity, to: zhu.Vector2) bool {
    return spatial.canMove(world, entity, to);
}

fn thingAt(world: *World, tile: Land.Tile) ?Maps.Thing {
    const object = tile.object orelse return null;
    return switch (object.kind) {
        .crop => .{ .crop = world.get(object.entity, farm.Crop).? },
        .chest => .{ .chest = world.get(object.entity, item.Chest).? },
        .product => .{ .product = .{
            .product = world.get(object.entity, item.Product).?,
            .health = world.get(object.entity, item.Health).?,
        } },
    };
}

fn restoreState(world: *World, savedMaps: *Maps, day: u32) void {
    const state = savedMaps.ensure(current, land.tiles.len, day);
    advanceState(state, day);

    for (state.tiles, 0..) |saved, index| {
        const tile = &land.tiles[index];
        tile.ground = saved.ground;

        const thing = saved.thing orelse continue;
        restoreThing(world, index, thing);
    }

    state.day = day;
}

fn restoreThing(world: *World, index: usize, thing: Thing) void {
    switch (thing) {
        .gone => clearProductIndex(world, index),
        .crop => |crop| {
            const position = grid.indexToWorld(index);
            const entity = factory.spawnCrop(world, position, crop.kind);
            world.getPtr(entity, farm.Crop).?.* = crop;
            refreshCropSprite(world, entity, crop);
            land.tiles[index].set(.crop, entity);
        },
        .chest => |saved| {
            const object = land.tiles[index].object.?;
            std.debug.assert(object.kind == .chest);
            const chest = world.getPtr(object.entity, item.Chest).?;
            chest.* = saved;
            if (!saved.opened) return;

            const animation = world.getPtr(object.entity, actor.Animation).?;
            const sprite = world.getPtr(object.entity, render.Sprite).?;
            // 已打开宝箱只需要固定打开帧，后续不再参与动画系统。
            sprite.image = animation.subImageAt(animation.clip.len - 1);
            world.remove(object.entity, actor.Animation);
            world.remove(object.entity, motion.Shape);
        },
        .product => |saved| {
            const object = land.tiles[index].object.?;
            std.debug.assert(object.kind == .product);
            world.getPtr(object.entity, item.Product).?.* = saved.product;
            world.getPtr(object.entity, item.Health).?.* = saved.health;
        },
    }
}

// 清除地图上的默认产出对象，并记录为 gone，避免后续恢复时重新生成。
pub fn clearProduct(world: *World, position: zhu.Vector2) void {
    clearProductIndex(world, grid.worldToIndex(position).?);
}

fn clearProductIndex(world: *World, index: usize) void {
    const object = land.tiles[index].object.?;
    std.debug.assert(object.kind == .product);
    // 对象层产出会注册精确碰撞矩形；tile 层产出只写瓦片阻挡。
    if (world.get(object.entity, component.map.SolidRange)) |range| {
        spatial.clearSolidRange(range);
    } else {
        spatial.clearTileBlock(index);
    }
    world.destroyEntity(object.entity);
    clearProductTiles(object.entity);
    land.tiles[index].gone = .product;
}

// 只清引用，不写 gone；gone 只记录在触发销毁的那一个格子上。
fn clearProductTiles(entity: zhu.ecs.Entity) void {
    for (land.tiles) |*tile| {
        if (tile.get(.product) == entity) tile.object = null;
    }
}

fn advanceState(state: *Maps.Entry, day: u32) void {
    if (day <= state.day) return;

    const days = day - state.day;
    for (0..days) |_| advanceStateOneDay(state);
    state.day = day;
}

fn advanceStateOneDay(state: *Maps.Entry) void {
    for (state.tiles) |*tile| {
        const watered = tile.ground == .wet;
        // 浇水只影响当天，跨天后湿地统一变回干地。
        if (tile.ground == .wet) tile.ground = .dry;

        const thing = tile.thing orelse continue;
        switch (thing) {
            .crop => |cropState| {
                var crop = cropState;
                _ = advanceCropOneDay(&crop, watered);
                tile.thing = .{ .crop = crop };
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

fn refreshCropSprite(world: *World, entity: Entity, crop: farm.Crop) void {
    const cfg = factory.cropStage(crop.kind, crop.stage);
    world.getPtr(entity, render.Sprite).?.* = .{
        .image = factory.resolveImage(cfg.sprite),
        .offset = cfg.sprite.offset,
    };
    if (crop.stage == .seed) return;
    world.getPtr(entity, render.Render).?.layer = .actor;
}

pub fn drawBack() void {
    if (vertexes.items.len != 0) {
        const back = vertexes.items[0..frontLayerStart];
        zhu.batch.drawVertices(back, mapImage);
    }

    land.draw(dryLandImage, wetLandImage);
}

pub fn drawFront() void {
    if (frontLayerStart == vertexes.items.len) return;
    const front = vertexes.items[frontLayerStart..];
    zhu.batch.drawVertices(front, null);
}

fn triggerSpawnPosition(trigger: Trigger) zhu.Vector2 {
    const center = trigger.rect.center();
    return switch (trigger.startOffset) {
        .left => .xy(trigger.rect.min.x - triggerOffset, center.y),
        .right => .xy(trigger.rect.max().x + triggerOffset, center.y),
        .top => .xy(center.x, trigger.rect.min.y - triggerOffset),
        .bottom => .xy(center.x, trigger.rect.max().y + triggerOffset),
        .none => center,
    };
}

test "地图绘制会把前景留到实体之后" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    defer vertexes.clearAndFree(std.testing.allocator);

    vertexes.clearRetainingCapacity();
    frontLayerStart = 0;

    const image = zhu.Image{ .view = .{ .id = 1 } };
    mapImage = image;
    try vertexes.append(std.testing.allocator, .{
        .position = .xy(1, 0),
        .layer = image.layer,
        .size = image.size,
        .uvRect = image.uvRect(),
    });
    frontLayerStart = vertexes.items.len;
    try vertexes.append(std.testing.allocator, .{
        .position = .xy(2, 0),
        .layer = image.layer,
        .size = image.size,
        .uvRect = image.uvRect(),
    });

    var vertices: [8]zhu.batch.Vertex = undefined;
    var commands: [4]zhu.batch.Command = undefined;
    zhu.batch.init(&vertices, &commands);
    const vertexBuffer = &zhu.batch.vertices;

    drawBack();

    try std.testing.expectEqual(1, vertexBuffer.items.len);
    try std.testing.expectEqual(1, vertexBuffer.items[0].position.x);

    drawFront();

    try std.testing.expectEqual(2, vertexBuffer.items.len);
    try std.testing.expectEqual(2, vertexBuffer.items[1].position.x);
}

test "触发器落点会按 start_offset 放到区域外侧" {
    const trigger = Trigger{
        .rect = .init(.xy(10, 20), .xy(30, 40)),
        .selfId = 1,
        .targetId = 1,
        .targetMap = .school,
        .startOffset = .bottom,
    };

    const position = triggerSpawnPosition(trigger);

    try std.testing.expectEqual(25, position.x);
    try std.testing.expectEqual(68, position.y);
}

test "地图状态作物会按离线天数推进" {
    var tiles = [_]Maps.Tile{.{
        .ground = .wet,
        .thing = .{ .crop = .{
            .kind = .strawberry,
            .stage = .seed,
            .timer = 0,
            .next = 2,
        } },
    }};
    var state = Maps.Entry{
        .day = 1,
        .tiles = &tiles,
    };
    advanceState(&state, 2);

    const crop = switch (state.tiles[0].thing.?) {
        .crop => |crop| crop,
        else => unreachable,
    };
    try std.testing.expectEqual(farm.GrowthEnum.sprout, crop.stage);
    try std.testing.expectEqual(0, crop.timer);
    try std.testing.expectEqual(
        factory.cropStage(.strawberry, .sprout).duration,
        crop.next,
    );
    try std.testing.expectEqual(component.farm.Ground.dry, state.tiles[0].ground);
    try std.testing.expectEqual(@as(u32, 2), state.day);
}

test "湿地离线跨天只加速一天" {
    var tiles = [_]Maps.Tile{.{
        .ground = .wet,
        .thing = .{ .crop = .{
            .kind = .strawberry,
            .stage = .seed,
            .timer = 0,
            .next = 4,
        } },
    }};
    var state = Maps.Entry{
        .day = 1,
        .tiles = &tiles,
    };
    advanceState(&state, 3);

    const crop = switch (state.tiles[0].thing.?) {
        .crop => |crop| crop,
        else => unreachable,
    };
    try std.testing.expectEqual(farm.GrowthEnum.seed, crop.stage);
    try std.testing.expectEqual(@as(f32, 1), crop.next);
    try std.testing.expectEqual(component.farm.Ground.dry, state.tiles[0].ground);
}

test "成熟作物跨天不会继续推进" {
    var crop = farm.Crop{
        .kind = .potato,
        .stage = .mature,
        .timer = 3,
        .next = 7,
    };

    try std.testing.expect(!advanceCropOneDay(&crop, true));
    try std.testing.expectEqual(farm.GrowthEnum.mature, crop.stage);
    try std.testing.expectEqual(@as(f32, 3), crop.timer);
    try std.testing.expectEqual(@as(f32, 7), crop.next);
}

test "当前地图跨天推进作物后刷新贴图和渲染层" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockCropImages();
    land = Land.init(zhu.testing.allocator, maps[0].grid);
    defer land.deinit(zhu.testing.allocator);

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const target = zhu.Vector2.xy(32, 48);
    const crop = world.createEntity();
    world.add(crop, farm.Crop{
        .kind = .strawberry,
        .stage = .seed,
        .next = 1,
    });
    world.add(crop, render.Sprite{ .image = .{} });
    world.add(crop, render.Render{ .layer = .crop });
    const tile = land.getTile(target).?;
    tile.ground = .dry;
    tile.set(.crop, crop);
    world.addEvent(component.event.DayChanged{ .day = 2 });

    update(&world);

    const result = world.get(crop, farm.Crop).?;
    const stage = factory.cropStage(.strawberry, .sprout);
    try std.testing.expectEqual(farm.GrowthEnum.sprout, result.stage);
    try std.testing.expectEqual(stage.duration, result.next);
    try std.testing.expectEqual(stage.sprite.offset, world.get(crop, render.Sprite).?.offset);
    try std.testing.expectEqual(render.Layer.actor, world.get(crop, render.Render).?.layer);
}

test "当前地图和离线地图跨天推进规则一致" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockCropImages();
    land = Land.init(zhu.testing.allocator, maps[0].grid);
    defer land.deinit(zhu.testing.allocator);

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const target = zhu.Vector2.xy(32, 48);
    const cropEntity = world.createEntity();
    world.add(cropEntity, farm.Crop{
        .kind = .strawberry,
        .stage = .seed,
        .next = 2,
    });
    world.add(cropEntity, render.Sprite{ .image = .{} });
    world.add(cropEntity, render.Render{ .layer = .crop });
    const tile = land.getTile(target).?;
    tile.ground = .wet;
    tile.set(.crop, cropEntity);
    world.addEvent(component.event.DayChanged{ .day = 2 });

    var tiles = [_]Maps.Tile{.{
        .ground = .wet,
        .thing = .{ .crop = .{
            .kind = .strawberry,
            .stage = .seed,
            .next = 2,
        } },
    }};
    var state = Maps.Entry{
        .day = 1,
        .tiles = &tiles,
    };
    update(&world);
    advanceState(&state, 2);

    const currentCrop = world.get(cropEntity, farm.Crop).?;
    const offlineCrop = switch (state.tiles[0].thing.?) {
        .crop => |crop| crop,
        else => unreachable,
    };
    try std.testing.expectEqual(offlineCrop.stage, currentCrop.stage);
    try std.testing.expectEqual(offlineCrop.next, currentCrop.next);
    try std.testing.expectEqual(offlineCrop.timer, currentCrop.timer);
    try std.testing.expectEqual(state.tiles[0].ground, tile.ground);
}

test "恢复已打开宝箱会移除动画组件" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    land = Land.init(zhu.testing.allocator, maps[0].grid);
    defer land.deinit(zhu.testing.allocator);

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const frames = [_]zhu.graphics.Frame{
        .{ .offset = .xy(0, 0), .duration = 0.1 },
        .{ .offset = .xy(16, 0), .duration = 0.1 },
    };
    const image = zhu.Image{ .size = .xy(32, 16) };

    const chest = world.createEntity();
    world.add(chest, item.Chest{});
    world.add(chest, actor.Animation.init(image, .xy(16, 16), &frames));
    world.add(chest, render.Sprite{ .image = image });
    land.tiles[0].object = .{ .kind = .chest, .entity = chest };

    restoreThing(&world, 0, .{ .chest = .{ .opened = true } });

    try std.testing.expect(world.get(chest, item.Chest).?.opened);
    try std.testing.expect(!world.has(chest, actor.Animation));
    try std.testing.expectEqual(16, world.get(chest, render.Sprite).?.image.offset.x);
}

test "恢复地图产出对象会写回保存的产物和生命" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    land = Land.init(zhu.testing.allocator, maps[0].grid);
    defer land.deinit(zhu.testing.allocator);

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, item.Product{ .item = .stone });
    world.add(entity, item.Health{ .value = 1 });
    land.tiles[0].object = .{ .kind = .product, .entity = entity };

    restoreThing(&world, 0, .{ .product = .{
        .product = .{ .item = .timber, .count = 2 },
        .health = .{ .value = 4 },
    } });

    const product = world.get(entity, item.Product).?;
    const health = world.get(entity, item.Health).?;
    try std.testing.expectEqual(.timber, product.item);
    try std.testing.expectEqual(2, product.count);
    try std.testing.expectEqual(4, health.value);
}

test "恢复 gone 会删除默认产出对象并清 tile 阻挡" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    land = Land.init(zhu.testing.allocator, maps[0].grid);
    defer land.deinit(zhu.testing.allocator);
    spatial = Spatial.init(zhu.testing.allocator, maps[0].grid);
    defer spatial.deinit(zhu.testing.allocator);

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, item.Product{ .item = .stone });
    world.add(entity, item.Health{ .value = 1 });
    land.tiles[0].object = .{ .kind = .product, .entity = entity };
    spatial.setTileFlag(0, "SOLID");

    restoreThing(&world, 0, .gone);

    const position = maps[0].grid.indexToWorld(0).add(.xy(1, 1));
    try std.testing.expectEqual(null, land.tiles[0].object);
    try std.testing.expectEqual(.product, land.tiles[0].gone);
    try std.testing.expect(!world.has(entity, item.Product));
    try std.testing.expect(!Spatial.hasAnyBlock(spatial.marksAt(position)));
}

test "保存已消失产出对象会写成 gone" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    land = Land.init(zhu.testing.allocator, maps[0].grid);
    defer land.deinit(zhu.testing.allocator);

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const old = current;
    current = .school;
    defer current = old;

    var mapsData: Maps = .{};
    const state = mapsData.ensure(current, land.tiles.len, 1);
    defer {
        zhu.assets.free(state.tiles);
        state.* = .{};
    }
    land.tiles[0].gone = .product;
    saveState(&world, &mapsData, 1);

    switch (state.tiles[0].thing.?) {
        .gone => {},
        else => return error.TestExpectedEqual,
    }
}

test "对象层产出对象按碰撞范围占用格子" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();

    const imageId = 4321;
    const tileSetId = 8765;
    zhu.assets.putImage(imageId, .{ .size = .xy(16, 16) });

    const treeProps = [_]tiled.Property{
        .{ .name = "obj_type", .value = .{ .string = "tree" } },
        .{ .name = "anim_id", .value = .{ .string = "axe" } },
    };
    const collisionObjects = [_]tiled.Object{.{
        .id = 1,
        .gid = 0,
        .name = "",
        .type = "",
        .position = .xy(16, 0),
        .size = .xy(16, 16),
        .point = false,
        .properties = &.{},
        .extend = .{},
    }};
    const objectGroup = tiled.ObjectGroup{
        .visible = true,
        .objects = &collisionObjects,
    };
    const tiles = [_]tiled.Tile{.{
        .id = 0,
        .objectGroup = objectGroup,
        .properties = &treeProps,
        .animation = &.{},
    }};
    const testTileSets = [_]tiled.TileSet{.{
        .id = tileSetId,
        .columns = 1,
        .tileCount = 1,
        .image = imageId,
        .tileSize = .xy(16, 16),
        .tiles = &tiles,
    }};
    const objects = [_]tiled.Object{.{
        .id = 1,
        .gid = 0x01000000,
        .name = "",
        .type = "",
        .position = .xy(0, 16),
        .size = .xy(32, 16),
        .point = false,
        .properties = &.{},
        .extend = .{},
    }};
    const layers = [_]tiled.Layer{.{
        .id = 1,
        .name = "main",
        .image = 0,
        .type = .object,
        .width = 0,
        .height = 0,
        .offset = .zero,
        .data = &.{},
        .objects = &objects,
    }};
    const testMap = tiled.Map{
        .grid = .{ .width = 3, .height = 1, .cell = 16 },
        .layers = &layers,
        .tileSets = &testTileSets,
    };

    grid = testMap.grid;
    defer grid = maps[@intFromEnum(current)].grid;

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    var loaded = loader.load(zhu.testing.allocator, &world, testMap);
    land = loaded.land;
    spatial = loaded.spatial;
    defer land.deinit(zhu.testing.allocator);
    defer spatial.deinit(zhu.testing.allocator);
    defer loaded.vertexes.clearAndFree(std.testing.allocator);

    spatial.tiles[0].insert(.arable);
    spatial.tiles[1].insert(.arable);

    const product = land.tiles[1].get(.product).?;
    try std.testing.expectEqual(null, land.tiles[0].object);
    try std.testing.expect(land.hoe(.xy(8, 8)));
    try std.testing.expect(!land.hoe(.xy(24, 8)));

    clearProduct(&world, testMap.grid.indexToWorld(1));

    try std.testing.expectEqual(null, land.tiles[0].object);
    try std.testing.expectEqual(null, land.tiles[1].object);
    try std.testing.expectEqual(.none, land.tiles[0].gone);
    try std.testing.expectEqual(.product, land.tiles[1].gone);
    try std.testing.expect(!world.has(product, item.Product));
}

test "当前地图跨天会推进作物并清干湿地" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    land = Land.init(zhu.testing.allocator, maps[0].grid);
    defer land.deinit(zhu.testing.allocator);

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const target = zhu.Vector2.xy(32, 48);
    const crop = world.createEntity();
    world.add(crop, farm.Crop{
        .kind = .strawberry,
        .stage = .seed,
        .next = 4,
    });
    const tile = land.getTile(target).?;
    tile.ground = .wet;
    tile.set(.crop, crop);
    world.addEvent(component.event.DayChanged{ .day = 2 });

    update(&world);

    const result = world.get(crop, farm.Crop).?;
    try std.testing.expectEqual(@as(f32, 2), result.next);
    try std.testing.expectEqual(component.farm.Ground.dry, tile.ground);
}

fn putMockCropImages() void {
    const image = zhu.Image{ .size = .xy(256, 256) };
    for (factory.zon.crops) |cropConfig| {
        for (cropConfig.stages) |stage| {
            zhu.assets.putImage(stage.sprite.imageId, image);
        }
    }
}
