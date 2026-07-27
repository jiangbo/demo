const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const math = zhu.math;

const zon = @import("zon.zig");
const component = @import("component.zig");
const Key = zon.Map.Key;
const Map = component.map.Map;
const Vertex = zhu.batch.Vertex;

var image: zhu.Image = undefined;

pub var portalKey: zon.Portal.Key = .start;

var vertexes: []Vertex = &.{};
var battleVertexes: []Vertex = undefined;

pub fn init(allocator: zhu.Allocator) void {
    image = zhu.getImage("maps1-sheet.png").?;
    battleVertexes = buildVertexes(allocator, .battle);
}

pub fn deinit(allocator: zhu.Allocator) void {
    allocator.free(vertexes);
    allocator.free(battleVertexes);
}

pub fn enter(allocator: zhu.Allocator, world: *ecs.World) Key {
    const portal = zon.Portal.get(portalKey);
    const data = zon.Map.get(portal.map);
    zhu.camera.bound = data.grid.size();

    allocator.free(vertexes);
    vertexes = buildVertexes(allocator, portal.map);
    spawnMap(world, data, vertexes);
    return portal.map;
}

// 创建普通地图实体，组件借用 map 持有的顶点。
fn spawnMap(
    world: *ecs.World,
    data: *const zon.Map,
    value: []const Vertex,
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

// 根据静态地图生成完整顶点。
fn buildVertexes(allocator: zhu.Allocator, key: Key) []Vertex {
    const data = zon.Map.get(key);
    var count: usize = 0;
    for ([_][]const u16{ data.back, data.ground }) |tiles| {
        for (tiles) |tileIndex| {
            if (tileIndex != 0) count += 1;
        }
    }

    const result = allocator.alloc(Vertex, count);
    const rowTiles: usize = @intFromFloat(@divExact(image.size.x, 34));
    const tileSize = data.grid.cellSize();
    var next: usize = 0;

    for ([_][]const u16{ data.back, data.ground }) |tiles| {
        for (tiles, 0..) |tileIndex, index| {
            if (tileIndex == 0) continue;

            const row: f32 = @floatFromInt(tileIndex / rowTiles);
            const col: f32 = @floatFromInt(tileIndex % rowTiles);
            const position = math.Vector2.xy(col * 34 + 1, row * 34 + 1);
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

pub fn drawBattle() void {
    zhu.batch.drawVertices(battleVertexes, image);
}
