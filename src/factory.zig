const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("component.zig");
const storage = @import("storage.zig");
const zon = @import("zon.zig");

const actor = component.actor;
const Portal = component.Portal;

// 根据地图配置和图集构建完整顶点。
pub fn mapVertexes(
    allocator: zhu.Allocator,
    image: zhu.Image,
    key: zon.Map.Key,
) []zhu.batch.Vertex {
    const data = zon.Map.get(key);
    var count: usize = 0;
    for ([_][]const u16{ data.back, data.ground }) |tiles| {
        for (tiles) |tileIndex| {
            if (tileIndex != 0) count += 1;
        }
    }

    const result = allocator.alloc(zhu.batch.Vertex, count);
    const rowTiles: usize = @intFromFloat(@divExact(image.size.x, 34));
    const tileSize = data.grid.cellSize();
    var next: usize = 0;

    for ([_][]const u16{ data.back, data.ground }) |tiles| {
        for (tiles, 0..) |tileIndex, index| {
            if (tileIndex == 0) continue;

            const row: f32 = @floatFromInt(tileIndex / rowTiles);
            const col: f32 = @floatFromInt(tileIndex % rowTiles);
            const position = zhu.Vector2.xy(col * 34 + 1, row * 34 + 1);
            const tile = image.sub(.init(position, tileSize));
            result[next] = .{
                .position = data.grid.indexToWorld(index),
                .layer = tile.layer,
                .size = tileSize,
                .uvRect = tile.uvRect(),
            };
            next += 1;
        }
    }
    return result;
}

// 根据地图配置和长期状态创建地图对象。
pub fn spawnMapObjects(world: *ecs.World, key: zon.Map.Key) void {
    const mapData = zon.Map.get(key);
    spawnPortals(world, mapData);
    spawnChests(world, mapData);
    spawnActors(world, mapData);
}

// 将地图中的相邻传送瓦片创建为区域实体。
fn spawnPortals(world: *ecs.World, mapData: *const zon.Map) void {
    var areas = std.EnumMap(zon.Portal.Key, zhu.Rect).init(.{});
    for (mapData.object, 0..) |value, index| {
        if (value < 5) continue;
        const key: zon.Portal.Key = @enumFromInt(value - 4);
        const tile = mapData.grid.indexToRect(index);
        if (areas.getPtr(key)) |area| {
            const min = area.min.min(tile.min);
            const max = area.max().max(tile.max());
            area.* = .fromMax(min, max);
        } else areas.put(key, tile);
    }

    var iterator = areas.iterator();
    while (iterator.next()) |portal| {
        world.add(world.createEntity(), Portal{
            .key = portal.key,
            .area = portal.value.*,
        });
    }
}

// 根据当前地图和长期状态创建宝箱实体。
fn spawnChests(world: *ecs.World, mapData: *const zon.Map) void {
    const opened = world.getGlobal(storage.OpenedChests).?;
    const atlas = zhu.getImage("maps1-sheet.png").?;
    const images = component.ChestImages{
        .closed = atlas.sub(.init(.xy(35, 511), .square(32))),
        .opened = atlas.sub(.init(.xy(69, 511), .square(32))),
    };
    for (mapData.chests) |place| {
        const isOpened = opened.isSet(place.id);
        const image = if (isOpened) images.opened else images.closed;
        const entity = world.createEntity();
        world.addAll(entity, .{
            component.Chest{ .id = place.id },
            images,
            mapData.grid.indexToWorld(place.tileIndex),
            component.Collider.init(
                .zero,
                mapData.grid.cellSize(),
            ),
            component.Sprite{ .image = image },
        });
        if (!isOpened) world.add(entity, component.Interact{});
    }
}

// 在指定逻辑位置创建玩家实体。
pub fn spawnPlayer(
    world: *ecs.World,
    position: zhu.Vector2,
    facing: actor.Facing,
) void {
    const collider = component.Collider.init(
        .xy(-8, -16),
        .xy(16, 16),
    );
    var animation = zon.Actor.animation(.player);
    animation.play(facing);
    const entity = world.createIdentity(actor.Player);
    world.addAll(entity, .{
        actor.Key.player,
        actor.Player{},
        position,
        facing,
        collider,
        component.Speed{ .value = 100 },
        animation,
        component.Sprite{
            .image = animation.subImage(),
            .anchor = .xy(0.5, 1),
        },
    });
}

// 根据人物和剧情进度创建当前对话。
pub fn actorTalk(
    key: zon.Actor.Key,
    progress: u8,
) ?component.dialog.Talk {
    const data = zon.Actor.get(key);
    const dialogues = data.dialogues orelse return null;
    const index: usize = if (progress > 4) 1 else 0;
    return zon.dialogues[dialogues[index]].lines;
}

// 根据人物和剧情进度取得当前移动速度。
pub fn actorSpeed(key: zon.Actor.Key, progress: u8) f32 {
    const data = zon.Actor.get(key);
    if (progress > 4) return data.panicSpeed orelse data.speed;
    return data.speed;
}

// 根据地图配置和长期状态创建人物实体。
fn spawnActors(world: *ecs.World, mapData: *const zon.Map) void {
    const deadActors = world.getGlobal(storage.DeadActors).?;
    const progress = world.getGlobal(storage.Progress).?.value;
    for (mapData.actors) |key| {
        if (deadActors.contains(key)) continue;
        if (zon.Actor.get(key).progress < progress) continue;
        spawnActor(world, key, progress);
    }
}

// 根据配置创建一个 NPC 实体。
fn spawnActor(
    world: *ecs.World,
    key: zon.Actor.Key,
    progress: u8,
) void {
    const data = zon.Actor.get(key);
    const entity = world.createEntity();
    var animation = zon.Actor.animation(key);
    animation.play(data.facing);
    world.addAll(entity, .{
        key,
        component.Position.xy(data.x + 16, data.y + 32),
        data.facing,
        component.Collider.init(.xy(-8, -16), .xy(16, 16)),
        animation,
        component.Sprite{
            .image = animation.subImage(),
            .anchor = .xy(0.5, 1),
        },
    });

    if (actorTalk(key, progress)) |talk| {
        world.add(entity, talk);
        if (!data.enemy) {
            world.add(entity, component.Interact{});
        }
    }

    if (data.enemy) {
        world.add(entity, actor.Enemy{
            .value = .init(.xy(-24, -40), .xy(48, 48)),
        });
    }

    const speed = actorSpeed(key, progress);
    if (speed == 0) return;
    world.addAll(entity, .{
        component.Speed{ .value = speed },
        actor.Wander{ .value = .init(0) },
    });
}

test "相邻瓦片创建一个传送区域实体" {
    const objects = [_]u8{
        1, 5, 5,
        1, 1, 1,
    };
    const mapData = zon.Map{
        .key = "test",
        .grid = .{ .width = 3, .height = 2, .cell = 32 },
        .back = &.{},
        .ground = &.{},
        .object = &objects,
    };

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();
    spawnPortals(&world, &mapData);

    var query = world.query(.{Portal});
    const entity = query.next().?;
    const portal = query.get(entity, Portal);
    try std.testing.expectEqual(zon.Portal.Key.cityToHome, portal.key);
    try std.testing.expectEqual(zhu.Vector2.xy(32, 0), portal.area.min);
    try std.testing.expectEqual(zhu.Vector2.xy(64, 32), portal.area.size);
    try std.testing.expectEqual(null, query.next());
}
