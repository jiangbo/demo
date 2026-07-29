const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const zon = @import("zon.zig");
const component = @import("component.zig");
const storage = @import("storage.zig");

const actor = component.actor;
const Player = actor.Player;
const Position = component.Position;

pub const Spawn = union(enum) {
    location: storage.Location,
    portal: zon.Portal.Key,
};

var image: zhu.Image = undefined;

var vertexes: []zhu.batch.Vertex = &.{};

var field: zhu.extend.tiled.Field(u8) = undefined;

pub fn init() void {
    image = zhu.getImage("maps1-sheet.png").?;
}

pub fn deinit(allocator: zhu.Allocator) void {
    allocator.free(vertexes);
}

// 清空旧地图并按指定方式创建地图对象和玩家。
pub fn enter(
    world: *ecs.World,
    allocator: zhu.Allocator,
    spawn: Spawn,
) void {
    world.resetKeep(storage.keep);
    world.entity = world.createEntity();

    const mapKey = switch (spawn) {
        .location => |value| value.map,
        .portal => |portal| zon.Portal.get(portal).map,
    };
    const data = zon.Map.get(mapKey);
    zhu.camera.bound = data.grid.size();
    field = .{ .grid = data.grid, .data = data.object };

    allocator.free(vertexes);
    vertexes = allocator.alloc(zhu.batch.Vertex, data.tileCount());
    data.fillVertexes(image, vertexes);
    spawnPortals(world, data);
    spawnChests(world, data);
    spawnActors(world, data);

    const location = switch (spawn) {
        .location => |value| value,
        .portal => |key| portalLocation(world, key),
    };
    spawnPlayer(world, location);

    const player = world.getIdentity(Player).?;
    zhu.camera.directFollow(world.get(player, Position).?);
    zhu.camera.roundPosition(null);
}

// 绘制当前普通地图。
pub fn draw() void {
    zhu.batch.drawVertices(vertexes, image);
}

// 将区域移动到当前地图允许到达的位置。
pub fn walk(area: zhu.Rect, offset: zhu.Vector2) zhu.Rect {
    var moved = area;
    moved.min.x = limit(field.scanX(moved, offset.x));
    moved.min.y = limit(field.scanY(moved, offset.y));
    return moved;
}

// 碰撞后将移动位置限制到瓦片边缘。
fn limit(scanValue: zhu.extend.tiled.Scan(u8)) f32 {
    var scan = scanValue;
    while (scan.next()) |value| {
        switch (value) {
            1, 3, 4 => return scan.touch,
            else => continue,
        }
    }
    return scan.dest;
}

// 将地图中的相邻传送瓦片创建为区域实体。
fn spawnPortals(world: *ecs.World, data: *const zon.Map) void {
    var areas = std.EnumMap(zon.Portal.Key, zhu.Rect).init(.{});
    for (data.object, 0..) |value, index| {
        if (value < 5) continue;
        const key: zon.Portal.Key = @enumFromInt(value - 4);
        const tile = data.grid.indexToRect(index);
        if (areas.getPtr(key)) |area| {
            const min = area.min.min(tile.min);
            const max = area.max().max(tile.max());
            area.* = .fromMax(min, max);
        } else areas.put(key, tile);
    }

    var iterator = areas.iterator();
    while (iterator.next()) |portal| {
        world.add(world.createEntity(), component.Portal{
            .key = portal.key,
            .area = portal.value.*,
        });
    }
}

// 根据当前地图和长期状态创建宝箱实体。
fn spawnChests(world: *ecs.World, data: *const zon.Map) void {
    const opened = world.getGlobal(storage.OpenedChests).?;
    const images = component.ChestImages{
        .closed = image.sub(.init(.xy(35, 511), .square(32))),
        .opened = image.sub(.init(.xy(69, 511), .square(32))),
    };
    for (data.chests) |place| {
        const isOpened = opened.isSet(place.id);
        const chestImage = if (isOpened) images.opened else images.closed;
        const entity = world.createEntity();
        world.addAll(entity, .{
            component.Chest{ .id = place.id },
            images,
            data.grid.indexToWorld(place.tileIndex),
            component.Collider.init(.zero, data.grid.cellSize()),
            component.Sprite{ .image = chestImage },
        });
        if (!isOpened) world.add(entity, component.Interact{});
    }
}

// 根据地图配置和长期状态创建人物实体。
fn spawnActors(world: *ecs.World, data: *const zon.Map) void {
    const deadActors = world.getGlobal(storage.DeadActors).?;
    const progress = world.getGlobal(storage.Progress).?.value;
    for (data.actors) |key| {
        if (deadActors.contains(key)) continue;
        if (zon.Actor.get(key).progress < progress) continue;
        spawnActor(world, key, progress);
    }
}

// 根据配置创建一个 NPC 实体。
fn spawnActor(world: *ecs.World, key: zon.Actor.Key, progress: u8) void {
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

    if (data.dialogues != null) {
        world.add(entity, data.talk(progress));
        if (!data.enemy) world.add(entity, component.Interact{});
    }

    if (data.enemy) {
        world.add(entity, actor.Enemy{
            .value = .init(.xy(-24, -40), .xy(48, 48)),
        });
    }

    const speed = data.moveSpeed(progress);
    if (speed == 0) return;
    world.addAll(entity, .{
        component.Speed{ .value = speed },
        actor.Wander{ .value = .init(0) },
    });
}

// 在指定逻辑位置创建玩家实体。
fn spawnPlayer(
    world: *ecs.World,
    location: storage.Location,
) void {
    const collider = component.Collider.init(
        .xy(-8, -16),
        .xy(16, 16),
    );
    var animation = zon.Actor.animation(.player);
    animation.play(location.facing);
    const entity = world.createIdentity(Player);
    world.addAll(entity, .{
        actor.Key.player,
        Player{},
        location.map,
        location.position,
        location.facing,
        collider,
        component.Speed{ .value = 100 },
        animation,
        component.Sprite{
            .image = animation.subImage(),
            .anchor = .xy(0.5, 1),
        },
    });
}

// 取得目标传送区域外的玩家位置。
fn portalLocation(
    world: *ecs.World,
    key: zon.Portal.Key,
) storage.Location {
    const config = zon.Portal.get(key);
    if (key == .start) {
        return .{
            .map = config.map,
            .position = .xy(188, 180),
            .facing = config.facing,
        };
    }

    var query = world.query(.{component.Portal});
    while (query.next()) |entity| {
        const portal = query.get(entity, component.Portal);
        if (portal.key != key) continue;

        const center = portal.area.center();
        const max = portal.area.max();
        const position = switch (config.facing) {
            .down => zhu.Vector2.xy(center.x, max.y + 24),
            .left => zhu.Vector2.xy(
                portal.area.min.x - 16,
                center.y + 8,
            ),
            .up => zhu.Vector2.xy(
                center.x,
                portal.area.min.y - 8,
            ),
            .right => zhu.Vector2.xy(max.x + 16, center.y + 8),
        };
        return .{
            .map = config.map,
            .position = position,
            .facing = config.facing,
        };
    }
    unreachable;
}

test "地图瓦片移动" {
    const objects = [_]u8{
        1, 1, 1,
        1, 0, 1,
        1, 1, 1,
    };
    field = .{
        .grid = .{ .width = 3, .height = 3, .cell = 32 },
        .data = &objects,
    };

    const area = zhu.Rect.init(.xy(40, 40), .square(16));

    var moved = walk(area, .xy(20, 0));
    try std.testing.expectEqual(48, moved.min.x);
    try std.testing.expectEqual(40, moved.min.y);

    moved = walk(area, .xy(-20, 0));
    try std.testing.expectEqual(32, moved.min.x);

    moved = walk(area, .xy(0, 20));
    try std.testing.expectEqual(48, moved.min.y);

    moved = walk(area, .xy(0, -20));
    try std.testing.expectEqual(32, moved.min.y);

    const passable = [_]u8{
        1, 1, 1,
        1, 0, 5,
        1, 1, 1,
    };
    field.data = &passable;
    moved = walk(area, .xy(20, 0));
    try std.testing.expectEqual(60, moved.min.x);
}

test "相邻瓦片创建一个传送区域实体" {
    const objects = [_]u8{
        1, 5, 5,
        1, 1, 1,
    };
    const data = zon.Map{
        .key = "test",
        .grid = .{ .width = 3, .height = 2, .cell = 32 },
        .back = &.{},
        .ground = &.{},
        .object = &objects,
    };

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();
    spawnPortals(&world, &data);

    var query = world.query(.{component.Portal});
    const entity = query.next().?;
    const portal = query.get(entity, component.Portal);
    try std.testing.expectEqual(zon.Portal.Key.cityToHome, portal.key);
    try std.testing.expectEqual(zhu.Vector2.xy(32, 0), portal.area.min);
    try std.testing.expectEqual(zhu.Vector2.xy(64, 32), portal.area.size);
    try std.testing.expectEqual(null, query.next());
}
