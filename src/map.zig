const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const zon = @import("zon.zig");
const component = @import("component.zig");
const factory = @import("factory.zig");
const storage = @import("storage.zig");
const Collider = component.Collider;
const Facing = component.actor.Facing;
const Map = component.map.Map;
const Player = component.actor.Player;
const Portal = component.map.Portal;
const Position = component.Position;

pub const Location = struct {
    portal: zon.Portal.Key,
    position: zhu.Vector2,
    facing: Facing,
};

pub const Spawn = union(enum) {
    location: Location,
    portal: zon.Portal.Key,
};

var image: zhu.Image = undefined;

pub var portalKey: zon.Portal.Key = .start;

var vertexes: []zhu.batch.Vertex = &.{};

pub fn init(world: *ecs.World) void {
    image = zhu.getImage("maps1-sheet.png").?;
    reset(world);
}

// 重置新游戏使用的长期状态。
pub fn reset(world: *ecs.World) void {
    world.addAll(world.entity, .{
        storage.DeadActors.empty,
        storage.OpenedChests.initEmpty(),
        storage.Progress{},
        storage.Stats{},
        storage.Inventory{},
    });
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

    const key = switch (spawn) {
        .location => |location| location.portal,
        .portal => |portal| portal,
    };
    portalKey = key;
    const portal = zon.Portal.get(portalKey);
    const data = zon.Map.get(portal.map);
    zhu.camera.bound = data.grid.size();

    allocator.free(vertexes);
    vertexes = factory.mapVertexes(allocator, image, portal.map);
    spawnMap(world, data, vertexes);
    factory.spawnMapObjects(world, portal.map);

    switch (spawn) {
        .location => |location| factory.spawnPlayer(
            world,
            location.position,
            location.facing,
        ),
        .portal => |portalKey_| spawnPlayerAtPortal(
            world,
            portalKey_,
        ),
    }
}

// 读取存档并恢复跨地图长期状态。
pub fn load(world: *ecs.World, index: u8) !Location {
    var loaded = try storage.read(index);
    defer loaded.deinit();

    const record = loaded.value;
    world.addAll(world.entity, .{
        record.progress,
        record.stats,
        record.inventory,
    });

    const opened = world.getGlobal(storage.OpenedChests).?;
    opened.* = .initEmpty();
    for (record.openedChests) |chestId| {
        opened.set(chestId);
    }

    const deadActors = world.getGlobal(storage.DeadActors).?;
    deadActors.* = .empty;
    for (record.deadActors) |actorKey| {
        deadActors.insert(actorKey);
    }

    return .{
        .portal = record.portal,
        .position = record.position,
        .facing = record.facing,
    };
}

// 收集当前地图和长期状态并写入存档。
pub fn save(world: *ecs.World, index: u8) !void {
    var openedChestBuffer: [zon.Chest.list.len]u16 = undefined;
    var openedChestCount: usize = 0;
    const opened = world.getGlobal(storage.OpenedChests).?;
    var chestIterator = opened.iterator(.{});
    while (chestIterator.next()) |chestId| {
        openedChestBuffer[openedChestCount] = @intCast(chestId);
        openedChestCount += 1;
    }

    var deadKeys: [storage.DeadActors.len]zon.Actor.Key = undefined;
    var deadActorCount: usize = 0;
    const deadActors = world.getGlobal(storage.DeadActors).?;
    var actorIterator = deadActors.iterator();
    while (actorIterator.next()) |actorKey| {
        deadKeys[deadActorCount] = actorKey;
        deadActorCount += 1;
    }

    const player = world.getIdentity(Player).?;
    try storage.write(index, .{
        .portal = portalKey,
        .position = playerPosition(world),
        .facing = world.get(player, Facing).?,
        .progress = world.getGlobal(storage.Progress).?.*,
        .stats = world.getGlobal(storage.Stats).?.*,
        .inventory = world.getGlobal(storage.Inventory).?.*,
        .openedChests = openedChestBuffer[0..openedChestCount],
        .deadActors = deadKeys[0..deadActorCount],
    });
}

// 返回玩家碰撞区域的位置。
pub fn playerPosition(world: *ecs.World) zhu.Vector2 {
    const entity = world.getIdentity(Player).?;
    const position = world.get(entity, Position).?;
    const collider = world.get(entity, Collider).?;
    return collider.move(position).min;
}

// 在目标传送区域外创建玩家。
fn spawnPlayerAtPortal(world: *ecs.World, key: zon.Portal.Key) void {
    const config = zon.Portal.get(key);
    var query = world.query(.{Portal});
    while (query.next()) |entity| {
        const portal = query.get(entity, Portal);
        if (portal.key != key) continue;

        const center = portal.area.center();
        const max = portal.area.max();
        const position = switch (config.facing) {
            .down => zhu.Vector2.xy(center.x - 8, max.y + 8),
            .left => zhu.Vector2.xy(
                portal.area.min.x - 16 - 8,
                center.y - 8,
            ),
            .up => zhu.Vector2.xy(
                center.x - 8,
                portal.area.min.y - 16 - 8,
            ),
            .right => zhu.Vector2.xy(max.x + 8, center.y - 8),
        };
        factory.spawnPlayer(world, position, config.facing);
        return;
    }
    unreachable;
}

// 创建普通地图实体，组件借用 map 持有的顶点。
fn spawnMap(
    world: *ecs.World,
    data: *const zon.Map,
    value: []const zhu.batch.Vertex,
) void {
    const entity = world.createIdentity(Map);
    world.addAll(entity, .{
        Map{ .image = image, .vertexes = value },
        component.map.Static{
            .grid = data.grid,
            .data = data.object,
        },
    });
}
