const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const zon = @import("zon.zig");
const component = @import("component.zig");
const factory = @import("factory.zig");
const storage = @import("storage.zig");
const Facing = component.actor.Facing;
const Map = component.map.Map;
const Player = component.actor.Player;
const Portal = component.map.Portal;
const Position = component.Position;

pub const Spawn = union(enum) {
    location: storage.Location,
    portal: zon.Portal.Key,
};

var image: zhu.Image = undefined;

var current: zon.Map.Key = .home;

var vertexes: []zhu.batch.Vertex = &.{};

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

    current = switch (spawn) {
        .location => |value| value.map,
        .portal => |portal| zon.Portal.get(portal).map,
    };
    const data = zon.Map.get(current);
    zhu.camera.bound = data.grid.size();

    allocator.free(vertexes);
    vertexes = factory.mapVertexes(allocator, image, current);
    spawnMap(world, data, vertexes);
    factory.spawnMapObjects(world, current);

    switch (spawn) {
        .location => |value| factory.spawnPlayer(
            world,
            value.position,
            value.facing,
        ),
        .portal => |portalKey_| spawnPlayerAtPortal(
            world,
            portalKey_,
        ),
    }

    zhu.camera.directFollow(location(world).position);
    zhu.camera.roundPosition(null);
}

// 返回当前地图和玩家位置。
pub fn location(world: *ecs.World) storage.Location {
    const player = world.getIdentity(Player).?;
    return .{
        .map = current,
        .position = world.get(player, Position).?,
        .facing = world.get(player, Facing).?,
    };
}

// 在目标传送区域外创建玩家。
fn spawnPlayerAtPortal(world: *ecs.World, key: zon.Portal.Key) void {
    const config = zon.Portal.get(key);
    if (key == .start) {
        factory.spawnPlayer(world, .xy(188, 180), config.facing);
        return;
    }

    var query = world.query(.{Portal});
    while (query.next()) |entity| {
        const portal = query.get(entity, Portal);
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
