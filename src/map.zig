const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const zon = @import("zon.zig");
const component = @import("component.zig");
const factory = @import("factory.zig");
const Key = zon.Map.Key;
const Map = component.map.Map;

var image: zhu.Image = undefined;

pub var portalKey: zon.Portal.Key = .start;

var vertexes: []zhu.batch.Vertex = &.{};

pub fn init() void {
    image = zhu.getImage("maps1-sheet.png").?;
}

pub fn deinit(allocator: zhu.Allocator) void {
    allocator.free(vertexes);
}

pub fn enter(allocator: zhu.Allocator, world: *ecs.World) Key {
    const portal = zon.Portal.get(portalKey);
    const data = zon.Map.get(portal.map);
    zhu.camera.bound = data.grid.size();

    allocator.free(vertexes);
    vertexes = factory.mapVertexes(allocator, image, portal.map);
    spawnMap(world, data, vertexes);
    return portal.map;
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
