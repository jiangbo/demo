const std = @import("std");
const zhu = @import("zhu");

const math = zhu.math;
const tiled = zhu.extend.tiled;

const item = @import("item.zig");
const zon = @import("zon.zig");
const Facing = @import("component.zig").Facing;

var texture: zhu.Image = undefined;
var rowTiles: usize = 0;
var objectField: tiled.Field(u8) = undefined;

pub var linkIndex: u8 = 4;
pub var current: *const zon.Map = undefined;

var vertexBuffer: [2000]zhu.batch.Vertex = undefined;
var vertexArray: std.ArrayListUnmanaged(zhu.batch.Vertex) = undefined;
var backgroundIndex: usize = undefined;

pub fn init() void {
    vertexArray = .initBuffer(&vertexBuffer);
    texture = zhu.getImage("maps1-sheet.png").?;
    rowTiles = @intFromFloat(@divExact(texture.size.x, 34));
}

pub fn enter() math.Vector2 {
    const link = zon.links[linkIndex];
    current = &zon.maps[link.mapId];
    objectField = .{ .grid = current.grid, .data = current.object };

    vertexArray.clearRetainingCapacity();

    buildVertexBuffer(current.back);
    buildVertexBuffer(current.ground);
    backgroundIndex = vertexArray.items.len;
    for (current.chests) |chest| {
        if (item.picked.isSet(chest.pickupIndex))
            appendVertex(302, chest.tileIndex)
        else
            appendVertex(301, chest.tileIndex);
    }

    return link.player;
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
    if (current.object[index] != 2) return null;

    for (current.chests) |chest| {
        if (index != chest.tileIndex) continue;
        // 宝箱已经被打开，不需要处理任何东西
        if (item.picked.isSet(chest.pickupIndex)) return null;
        return @intCast(chest.pickupIndex);
    }
    unreachable;
}

pub fn openChest(pickIndex: usize) void {
    // back 和 ground 已经填充的顶点不需要修改，修改宝箱的顶点

    for (current.chests, 0..) |chest, index| {
        if (pickIndex != chest.pickupIndex) continue;

        item.picked.set(pickIndex);
        const vertex = buildVertex(302, chest.tileIndex);
        vertexArray.items[backgroundIndex + index] = vertex;
        return;
    }
    unreachable;
}

pub fn objectAt(position: zhu.Vector2) u8 {
    const cell = current.grid.worldToCell(position);
    return objectField.tileAt(cell).?;
}

pub fn walkTo(area: math.Rect, velocity: math.Vector2) math.Vector2 {
    var moved = area;
    var scan = objectField.scanX(moved, velocity.x);
    moved.min.x = scan.dest;
    while (scan.next()) |object| {
        if (object == 0 or object > 4) continue;
        moved.min.x = scan.touch;
        break;
    }

    scan = objectField.scanY(moved, velocity.y);
    moved.min.y = scan.dest;
    while (scan.next()) |object| {
        if (object == 0 or object > 4) continue;
        moved.min.y = scan.touch;
        break;
    }

    return moved.min;
}

pub fn draw() void {
    zhu.batch.drawVertices(vertexArray.items, texture);
}

test "地图瓦片移动" {
    const objects = [_]u8{
        1, 1, 1,
        1, 0, 1,
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
