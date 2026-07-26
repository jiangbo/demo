const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const math = zhu.math;
const tiled = zhu.extend.tiled;

const item = @import("item.zig");
const zon = @import("zon.zig");
const component = @import("component.zig");
const Facing = component.actor.Facing;
const Portal = component.Portal;

const MapCell = union(enum) {
    open,
    solid,
    chest,
    portal: zon.Portal.Key,

    // 将地图文件中的数字转换为游戏语义。
    fn from(value: u8) MapCell {
        return switch (value) {
            0 => .open,
            2 => .chest,
            1, 3, 4 => .solid,
            else => .{ .portal = @enumFromInt(value - 4) },
        };
    }
};

var texture: zhu.Image = undefined;
var rowTiles: usize = 0;
var objectField: tiled.Field(u8) = undefined;

pub var portalKey: zon.Portal.Key = .start;
pub var current: *const zon.Map = undefined;

var vertexBuffer: [2000]zhu.batch.Vertex = undefined;
var vertexArray: std.ArrayListUnmanaged(zhu.batch.Vertex) = undefined;
var backgroundIndex: usize = undefined;

pub fn init() void {
    vertexArray = .initBuffer(&vertexBuffer);
    texture = zhu.getImage("maps1-sheet.png").?;
    rowTiles = @intFromFloat(@divExact(texture.size.x, 34));
}

pub fn enter() void {
    const portal = zon.Portal.get(portalKey);
    current = &zon.maps[portal.mapId];
    objectField = .{ .grid = current.grid, .data = current.object };

    vertexArray.clearRetainingCapacity();

    buildVertexBuffer(current.back);
    buildVertexBuffer(current.ground);
    backgroundIndex = vertexArray.items.len;
    for (current.chests) |chest| {
        if (item.picked.isSet(chest.id))
            appendVertex(302, chest.tileIndex)
        else
            appendVertex(301, chest.tileIndex);
    }
}

fn buildVertexBuffer(tiles: []const u16) void {
    for (tiles, 0..) |tileIndex, index| {
        if (tileIndex != 0) appendVertex(tileIndex, index);
    }
}

fn appendVertex(tileIndex: usize, index: usize) void {
    vertexArray.appendAssumeCapacity(buildVertex(tileIndex, index));
}

fn buildVertex(tileIndex: usize, index: usize) zhu.batch.Vertex {
    const row: f32 = @floatFromInt(tileIndex / rowTiles);
    const col: f32 = @floatFromInt(tileIndex % rowTiles);
    const pos = math.Vector2.xy(col * 34 + 1, row * 34 + 1);
    const tileSize = current.grid.cellSize();

    const tile = texture.sub(.init(pos, tileSize));
    return zhu.batch.Vertex{
        .position = current.grid.indexToWorld(index),
        .layer = tile.layer,
        .size = tileSize,
        .uvRect = tile.uvRect(),
    };
}

pub fn talk(position: zhu.Vector2, facing: Facing) ?u16 {
    var cell = current.grid.worldToCell(position);
    switch (facing) {
        .down => cell.y += 1,
        .left => cell.x -= 1,
        .right => cell.x += 1,
        .up => cell.y -= 1,
    }

    const index = current.grid.cellToIndex(cell) orelse return null;
    switch (MapCell.from(current.object[index])) {
        .chest => {},
        else => return null,
    }

    for (current.chests) |chest| {
        if (index != chest.tileIndex) continue;
        // 宝箱已经被打开，不需要处理任何东西
        if (item.picked.isSet(chest.id)) return null;
        return chest.id;
    }
    unreachable;
}

pub fn openChest(chestId: u16) void {
    // back 和 ground 已经填充的顶点不需要修改，修改宝箱的顶点

    for (current.chests, 0..) |chest, index| {
        if (chestId != chest.id) continue;

        item.picked.set(chestId);
        const vertex = buildVertex(302, chest.tileIndex);
        vertexArray.items[backgroundIndex + index] = vertex;
        return;
    }
    unreachable;
}

// 将当前地图中的传送区域创建为实体。
pub fn spawnPortals(world: *ecs.World) void {
    var areas = std.EnumMap(zon.Portal.Key, math.Rect).init(.{});
    for (current.object, 0..) |value, index| {
        const key = switch (MapCell.from(value)) {
            .portal => |key| key,
            else => continue,
        };
        const tile = current.grid.indexToRect(index);
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

pub fn walkTo(area: math.Rect, velocity: math.Vector2) math.Vector2 {
    var moved = area;
    moved.min.x = limit(objectField.scanX(moved, velocity.x));
    moved.min.y = limit(objectField.scanY(moved, velocity.y));
    return moved.min;
}

// 当前地图采用碰撞后移动到瓦片边缘的策略。
fn limit(scanValue: tiled.Scan(u8)) f32 {
    var scan = scanValue;
    while (scan.next()) |value| {
        switch (MapCell.from(value)) {
            .open, .portal => continue,
            .solid, .chest => return scan.touch,
        }
    }
    return scan.dest;
}

pub fn draw() void {
    zhu.batch.drawVertices(vertexArray.items, texture);
}

test "相邻瓦片创建一个传送区域实体" {
    const objects = [_]u8{
        1, 5, 5,
        1, 1, 1,
    };
    const mapData = zon.Map{
        .grid = .{ .width = 3, .height = 2, .cell = 32 },
        .back = &.{},
        .ground = &.{},
        .object = &objects,
    };
    current = &mapData;

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();
    spawnPortals(&world);

    var query = world.query(.{Portal});
    const entity = query.next().?;
    const portal = query.get(entity, Portal);
    try std.testing.expectEqual(zon.Portal.Key.cityToHome, portal.key);
    try std.testing.expectEqual(math.Vector2.xy(32, 0), portal.area.min);
    try std.testing.expectEqual(math.Vector2.xy(64, 32), portal.area.size);
    try std.testing.expectEqual(null, query.next());
}

test "地图瓦片移动" {
    const objects = [_]u8{
        1, 1, 1,
        1, 0, 2,
        1, 1, 1,
    };
    objectField = .{
        .grid = .{ .width = 3, .height = 3, .cell = 32 },
        .data = &objects,
    };

    const area = math.Rect.init(.xy(40, 40), .square(16));

    var moved = walkTo(area, .xy(20, 0));
    try std.testing.expectEqual(@as(f32, 48), moved.x);
    try std.testing.expectEqual(@as(f32, 40), moved.y);

    moved = walkTo(area, .xy(-20, 0));
    try std.testing.expectEqual(@as(f32, 32), moved.x);

    moved = walkTo(area, .xy(0, 20));
    try std.testing.expectEqual(@as(f32, 48), moved.y);

    moved = walkTo(area, .xy(0, -20));
    try std.testing.expectEqual(@as(f32, 32), moved.y);

    const passable = [_]u8{
        1, 1, 1,
        1, 0, 5,
        1, 1, 1,
    };
    objectField.data = &passable;
    moved = walkTo(area, .xy(20, 0));
    try std.testing.expectEqual(@as(f32, 60), moved.x);
}
