const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const zon = @import("zon.zig");
const component = @import("component.zig");
const factory = @import("factory.zig");
const storage = @import("storage.zig");
const Player = component.actor.Player;
const Portal = component.Portal;
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

    const key = switch (spawn) {
        .location => |value| value.map,
        .portal => |portal| zon.Portal.get(portal).map,
    };
    const data = zon.Map.get(key);
    zhu.camera.bound = data.grid.size();
    field = .{ .grid = data.grid, .data = data.object };

    allocator.free(vertexes);
    vertexes = factory.mapVertexes(allocator, image, key);
    factory.spawnMapObjects(world, key);

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

    const player = world.getIdentity(Player).?;
    world.add(player, key);
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
