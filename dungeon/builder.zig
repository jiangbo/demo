const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");

const TileRect = component.TileRect;
const Tile = component.Tile;
const TilePosition = component.TilePosition;

pub const WIDTH: usize = 80;
pub const HEIGHT: usize = 50;

pub fn buildRooms(tiles: []Tile, rooms: []TileRect) void {
    for (0..rooms.len) |roomIndex| {
        var room: TileRect = undefined;
        label: {
            room = TileRect{
                .x = zhu.randomInt(u8, 1, WIDTH - 10),
                .y = zhu.randomInt(u8, 1, HEIGHT - 10),
                .w = zhu.randomInt(u8, 2, 10),
                .h = zhu.randomInt(u8, 2, 10),
            };

            for (0..roomIndex) |idx| {
                if (rooms[idx].intersect(room)) break :label;
            }
        }

        for (room.y..room.y + room.h) |y| {
            for (room.x..room.x + room.w) |x| {
                setTile(tiles, x, y, .floor);
            }
        }
        rooms[roomIndex] = room;
    }
}

pub fn buildCorridors(tiles: []Tile, rooms: []TileRect) void {
    for (rooms[1..], 1..) |room, roomIndex| {
        const prev = rooms[roomIndex - 1].center();
        const new = room.center();
        if (zhu.randomInt(u8, 0, 2) == 1) {
            applyHorizontal(tiles, prev.x, new.x, prev.y);
            applyVertical(tiles, prev.y, new.y, new.x);
        } else {
            applyVertical(tiles, prev.y, new.y, prev.x);
            applyHorizontal(tiles, prev.x, new.x, new.y);
        }
    }
}

fn applyVertical(tiles: []Tile, y1: usize, y2: usize, x: usize) void {
    for (@min(y1, y2)..@max(y1, y2) + 1) |y| {
        setTile(tiles, x, y, .floor);
    }
}

fn applyHorizontal(tiles: []Tile, x1: usize, x2: usize, y: usize) void {
    for (@min(x1, x2)..@max(x1, x2) + 1) |x| {
        setTile(tiles, x, y, .floor);
    }
}

pub fn indexUsize(x: usize, y: usize) usize {
    return @min(x, WIDTH - 1) + @min(y, HEIGHT) * WIDTH;
}

pub fn setTile(tiles: []Tile, x: usize, y: usize, tile: Tile) void {
    tiles[indexUsize(x, y)] = tile;
}

var distances: [HEIGHT][WIDTH]u8 = undefined;
const Dequeue = std.PriorityDequeue(TilePosition, void, struct {
    fn compare(_: void, a: TilePosition, b: TilePosition) std.math.Order {
        return std.math.order(distances[a.y][a.x], distances[b.y][b.x]);
    }
}.compare);
const directions: [4]TilePosition = .{
    .{ .x = 1, .y = 0 }, .{ .x = 0xFF, .y = 0 },
    .{ .x = 0, .y = 1 }, .{ .x = 0, .y = 0xFF },
};
pub fn updateDistance(tiles: []const Tile, pos: TilePosition) void {
    for (&distances) |*row| @memset(row, 0xFF);

    var queue = Dequeue.init(zhu.window.allocator, {});
    defer queue.deinit();

    distances[pos.y][pos.x] = 0;
    queue.add(pos) catch unreachable;

    while (queue.removeMinOrNull()) |min| {
        const distance = distances[min.y][min.x];

        for (directions) |dir| {
            const x, const y = .{ min.x +% dir.x, min.y +% dir.y };
            if (x >= WIDTH or y >= HEIGHT) continue; // 超过地图
            if (tiles[indexUsize(x, y)] != .floor) continue; // 不可通过

            if (distance + 1 < distances[y][x]) {
                distances[y][x] = distance + 1;
                queue.add(.{ .x = x, .y = y }) catch unreachable;
            }
        }
    }
}

pub fn queryLessDistance(pos: TilePosition) ?TilePosition {
    const distance = distances[pos.y][pos.x];
    if (distance == 0) return null;

    var r1: ?TilePosition, var r2: ?TilePosition = .{ null, null };
    for (directions) |dir| {
        const x, const y = .{ pos.x +% dir.x, pos.y +% dir.y };
        if (x >= WIDTH or y >= HEIGHT) continue; // 超过地图

        if (distances[y][x] < distance) {
            const r = TilePosition{ .x = x, .y = y };
            if (distance > 4) return r; // 远距离直接返回
            if (r1 == null) r1 = r else r2 = r;
        }
    }
    if (r2 == null) return r1;
    return if (zhu.randomBool()) r1 else r2;
}
