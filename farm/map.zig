const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const factory = @import("factory.zig");
pub const spatial = @import("map/spatial.zig");
pub const land = @import("map/land.zig");

const tiled = zhu.extend.tiled;
const World = zhu.ecs.World;
const actor = component.actor;
const Position = component.Position;
pub const Id = component.map.Id;
pub const StartOffset = component.map.StartOffset;
const Trigger = component.map.Trigger;

pub const maps = [_]tiled.Map{
    @import("zon/map/school.zon"),
    @import("zon/map/town.zon"),
    @import("zon/map/exterior.zon"),
    @import("zon/map/interior.zon"),
};

const triggerOffset = 8;

pub var current: Id = .school;
pub var data: *const tiled.Map = &maps[0];
var vertexes: std.ArrayList(zhu.batch.Vertex) = .empty;
var frontLayerStart: usize = 0;
var mapImage: zhu.graphics.Image = undefined;

pub fn init() void {
    tiled.init(@import("zon/map/tile.zon"));
    mapImage = zhu.getImage("circle.png").?;
    land.init();
}

pub fn deinit() void {
    spatial.deinit();
    land.deinit();
    vertexes.clearAndFree(zhu.assets.allocator);
}

pub fn enter(world: *World, id: Id, targetId: i32) zhu.Vector2 {
    current = id;
    data = &maps[@intFromEnum(id)];
    zhu.camera.bound = data.size();

    land.enter(data);
    spatial.enter(data);

    parseLayers(world);

    var spawn: ?zhu.Vector2 = null;
    var query = world.query(.{Trigger});
    while (query.next()) |entity| {
        const trigger = query.get(entity, Trigger);
        if (trigger.selfId == targetId) {
            spawn = triggerSpawnPosition(trigger);
            break;
        }
    }

    var crops = world.query(.{ component.Position, component.farm.Crop });
    while (crops.next()) |entity| {
        const position = crops.get(entity, component.Position);
        const tile = land.getTile(position) orelse continue;
        tile.object = .{ .entity = entity };
    }

    zhu.camera.bound = data.size();
    const result = spawn orelse zhu.Vector2.xy(311, 168);
    zhu.camera.directFollow(result);

    return result;
}

fn parseLayers(world: *World) void {
    var foundFrontLayer = false;
    for (data.layers) |*layer| {
        std.log.info("parsing layer: {s}", .{layer.name});
        switch (layer.type) {
            .tile => if (layer.isNamed("solid")) {
                spatial.parseSolidLayer(layer);
            } else parseTileLayer(layer),
            .image => parseImageLayer(layer),
            .object => {
                if (!foundFrontLayer and layer.isNamed("main")) {
                    frontLayerStart = vertexes.items.len;
                    foundFrontLayer = true;
                }
                loadObjects(world, layer);
            },
        }
    }

    if (!foundFrontLayer) frontLayerStart = vertexes.items.len;

    std.log.info("map loaded: {}x{}, tiles: {}", //
        .{ data.width, data.height, vertexes.items.len });
}

pub fn exit(world: *World) void {
    world.destroyEntities(component.map.Scoped);
    land.exit();
    spatial.exit();
    frontLayerStart = 0;
    vertexes.clearRetainingCapacity();
}

pub fn drawBack() void {
    if (vertexes.items.len != 0) {
        const back = vertexes.items[0..frontLayerStart];
        zhu.batch.drawVertices(back, mapImage);
    }

    land.draw();
}

pub fn drawFront() void {
    if (frontLayerStart == vertexes.items.len) return;
    const front = vertexes.items[frontLayerStart..];
    zhu.batch.drawVertices(front, null);
}

// 对应 CPP 的 PROBE_PADDING_PX
const probePadding: f32 = 4;

/// 标记玩家正前方探测框范围内所有实体的 Hit 组件。
pub fn markFacingHits(world: *World) void {
    const player = world.getIdentity(actor.Player).?;
    const pos = world.get(player, Position).?;
    const facing = world.get(player, actor.Actor).?.facing;

    const ts = data.tileSize.x; // 当前地图瓦片大小
    const probeSize = ts + probePadding * 2;
    const half = probeSize / 2;
    const origin = pos.add(switch (facing) {
        .down => zhu.Vector2.xy(-half, ts - probePadding),
        .up => zhu.Vector2.xy(-half, -ts - half),
        .right => zhu.Vector2.xy(ts - probePadding, -half),
        .left => zhu.Vector2.xy(-ts - half, -half),
    });
    spatial.markHits(world, .init(origin, .square(probeSize)));
}

pub fn loadObjects(world: *World, layer: *const tiled.Layer) void {
    if (layer.isNamed("collider")) {
        for (layer.objects) |object| {
            spatial.addSolidRect(object.rect());
        }
        return;
    }

    for (layer.objects) |object| {
        loadObject(world, object);
    }
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

fn loadObject(world: *World, object: tiled.Object) void {
    if (object.point and object.isType("actor")) {
        // player 由 scene 统一创建，地图中的点只作为 Tiled 标记保留。
        if (object.isNamed("player")) return;

        if (object.isNamed("friend")) {
            const entity = factory.spawnFriend(world);
            // Tiled 点对象的位置就是 NPC 脚底点，和 YSort 使用同一套坐标。
            world.add(entity, object.position);
            world.getPtr(entity, actor.Wander).?.home = object.position;
            return;
        }
        std.debug.panic("unknown actor object: {s}", .{object.name});
    }

    // animal 是没有 gid 的 Tiled 点对象，name 直接对应 AnimalEnum。
    if (object.point and object.isType("animal")) {
        const kind = zhu.toEnum(actor.AnimalEnum, object.name);
        const entity = factory.spawnAnimal(world, kind);
        // Tiled 点对象的位置就是动物脚底点，和玩家、YSort 使用同一套坐标。
        world.add(entity, object.position);
        world.getPtr(entity, actor.Wander).?.home = object.position;
        return;
    }

    if (object.isType("map_trigger")) {
        std.debug.assert(object.size.x > 0 and object.size.y > 0);

        const target = object.getProperty("target_map", []const u8).?;
        const targetMap = zhu.toEnum(Id, target);
        const start = object.getProperty("start_offset", []const u8).?;
        const startOffset = std.meta.stringToEnum(StartOffset, start);

        const trigger: Trigger = .{
            .rect = object.rect(),
            .selfId = object.getProperty("self_id", i32).?,
            .targetId = object.getProperty("target_id", i32).?,
            .targetMap = targetMap,
            .startOffset = startOffset orelse .none,
        };
        _ = factory.spawnMapTrigger(world, trigger);
        return;
    }

    // rest 是后续休息区功能预留对象，本讲只明确识别，不生成实体。
    if (object.isType("rest")) return;

    if (object.isType("light")) {
        loadLightObject(world, object);
        return;
    }

    if (object.gid == 0) return;

    _ = factory.spawnMapProp(world, data, object);
    spatial.addSolidObject(object);
}

fn loadLightObject(world: *World, object: tiled.Object) void {
    if (object.isNamed("point")) {
        _ = factory.spawnPointLight(world, object);
        return;
    }

    if (object.isNamed("spot")) {
        _ = factory.spawnSpotLight(world, object);
    }
}

/// 将 tile 层的每个瓦片转为预构建顶点
/// 流程：gid → 找到所属 tileSet → 算出 tileSet 内的局部 ID
///       → 用 columns 换算行列得到裁剪区域 → sub 裁出子图 → 写入顶点
fn parseTileLayer(layer: *const tiled.Layer) void {
    for (layer.data, 0..) |globalId, index| {
        if (globalId == 0) continue; // 0 表示空瓦片，跳过

        const image = data.getImageByGid(globalId);
        const world = data.tileIndexToWorld(index);
        appendVertex(world, image);

        // 带 tile_flag 标记的瓦片设置方向碰撞
        const tile = data.getTileByGid(globalId) orelse continue;
        if (tile.getProperty("tile_flag", []const u8)) |flag| {
            spatial.setTileFlag(index, flag);
        }
    }
}

/// 将整张图作为一层背景/前景直接写入顶点
/// image 层没有瓦片网格，就是一张大图放在 offset 位置
fn parseImageLayer(layer: *const tiled.Layer) void {
    const image = zhu.assets.getImage(layer.image).?
        .sub(.init(.zero, .xy(layer.width, layer.height)));
    appendVertex(layer.offset, image);
}

fn appendVertex(position: zhu.Vector2, image: zhu.graphics.Image) void {
    vertexes.append(zhu.assets.allocator, .{
        .position = position,
        .size = image.size,
        .uvRect = image.uvRect(),
    }) catch @panic("map oom");
}

test "地图绘制会把前景留到实体之后" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    defer vertexes.clearAndFree(std.testing.allocator);

    vertexes.clearRetainingCapacity();
    frontLayerStart = 0;

    const image = zhu.Image{ .view = .{ .id = 1 } };
    mapImage = image;
    appendVertex(.xy(1, 0), image); // back
    frontLayerStart = vertexes.items.len;
    appendVertex(.xy(2, 0), image); // front

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

test "actor 点对象会生成 NPC，player 点对象只保留标记" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockNpcImages();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    loadObject(&world, .{
        .id = 1,
        .gid = 0,
        .name = "player",
        .type = "actor",
        .position = .xy(10, 20),
        .size = .zero,
        .point = true,
        .properties = &.{},
        .extend = .{},
    });

    try std.testing.expectEqual(0, world.assure(actor.Npc).dense.items.len);

    loadObject(&world, .{
        .id = 2,
        .gid = 0,
        .name = "friend",
        .type = "actor",
        .position = .xy(95, 274),
        .size = .zero,
        .point = true,
        .properties = &.{},
        .extend = .{},
    });

    var query = world.query(.{
        Position,
        actor.Npc,
        actor.Wander,
        actor.Dialog,
        component.map.Scoped,
    });
    const entity = query.next().?;
    const position = query.get(entity, Position);
    const wander = query.get(entity, actor.Wander);
    const dialog = query.get(entity, actor.Dialog);

    try std.testing.expectEqual(95, position.x);
    try std.testing.expectEqual(274, position.y);
    try std.testing.expectEqual(95, wander.home.x);
    try std.testing.expectEqual(274, wander.home.y);
    try std.testing.expect(dialog.lines.len != 0);
    try std.testing.expectEqual(null, query.next());
}

test "trigger 对象会创建 ECS 触发器实体" {
    const properties = [_]tiled.Property{
        .{ .name = "self_id", .value = .{ .int = 2 } },
        .{ .name = "start_offset", .value = .{ .string = "bottom" } },
        .{ .name = "target_id", .value = .{ .int = 3 } },
        .{ .name = "target_map", .value = .{ .string = "school" } },
    };

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    loadObject(&world, .{
        .id = 1,
        .gid = 0,
        .name = "",
        .type = "map_trigger",
        .position = .xy(10, 20),
        .size = .xy(30, 40),
        .point = false,
        .properties = &properties,
        .extend = .{},
    });

    var query = world.query(.{ component.map.Trigger, component.map.Scoped });
    const entity = query.next().?;
    const trigger = query.get(entity, component.map.Trigger);

    try std.testing.expectEqual(2, trigger.selfId);
    try std.testing.expectEqual(3, trigger.targetId);
    try std.testing.expectEqual(Id.school, trigger.targetMap);
    try std.testing.expectEqual(StartOffset.bottom, trigger.startOffset);
    try std.testing.expectEqual(10, trigger.rect.min.x);
    try std.testing.expectEqual(20, trigger.rect.min.y);
    try std.testing.expectEqual(null, query.next());
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

fn putMockNpcImages() void {
    const image = zhu.graphics.Image{ .size = .xy(192, 96) };
    zhu.assets.putImage(factory.zon.friend.sprite.imageId, image);
    for (factory.zon.friend.animations) |animation| {
        zhu.assets.putImage(animation.imageId, image);
    }
}
