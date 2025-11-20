const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");

const TileRect = component.TileRect;
const Tile = component.Tile;
const TilePosition = component.TilePosition;

pub const WIDTH: usize = 80;
pub const HEIGHT: usize = 50;
pub const SPAWN_SIZE = 20;

pub fn buildRooms(tiles: []Tile, spawns: []TilePosition) void {
    @memset(tiles, .wall);

    var rooms: [SPAWN_SIZE]TileRect = undefined;
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

    std.mem.sort(TileRect, &rooms, {}, compare);
    buildCorridors(tiles, &rooms);
    for (spawns, 0..) |*value, i| value.* = rooms[i].center();
}

fn compare(_: void, r1: TileRect, r2: TileRect) bool {
    return if (r1.x == r2.x) r1.y < r2.y else r1.x < r2.x;
}

fn buildCorridors(tiles: []Tile, rooms: []TileRect) void {
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

pub fn buildAutometa(tiles: []Tile, spawns: []TilePosition) void {
    for (tiles) |*value| {
        const roll = zhu.randomInt(u8, 0, 100);
        value.* = if (roll > 55) .floor else .wall;
    }

    for (0..10) |_| {
        var copy: [HEIGHT * WIDTH]Tile = undefined;
        @memcpy(&copy, tiles);
        for (1..HEIGHT - 1) |y| {
            for (1..WIDTH - 1) |x| {
                const dx: u8 = @intCast(x);
                const walls = countNeighborWall(&copy, dx, @intCast(y));
                const genWall = walls > 4 or walls == 0;
                tiles[indexUsize(x, y)] = if (genWall) .wall else .floor;
            }
        }
    }

    { // 放置玩家
        var x: u8, var y: u8 = .{ WIDTH / 2, WIDTH / 2 };
        blk: while (tiles[indexUsize(x, y)] == .wall) {
            for (neighborDir) |dir| {
                const dx, const dy = .{ x +% dir.x, y +% dir.y };
                if (tiles[indexUsize(dx, dy)] != .wall) {
                    spawns[0] = .{ .x = dx, .y = dy };
                    break :blk;
                }
            }
            const dir = neighborDir[zhu.randomIntMost(u8, 0, 7)];
            x, y = .{ x +% dir.x, y +% dir.y };
        } else spawns[0] = .{ .x = x, .y = y };
    }

    // 放置怪物
    for (spawns[1..]) |*value| {
        var pos = spawnRandomMonster(tiles);
        while (spawns[0].distanceSquared(pos) < 100) {
            pos = spawnRandomMonster(tiles);
        }
        value.* = pos;
    }
}

const neighborDir: [8]TilePosition = .{
    .{ .x = 0xFF, .y = 0xFF }, .{ .x = 0, .y = 0xFF },
    .{ .x = 1, .y = 0xFF },    .{ .x = 0xFF, .y = 0 },
    .{ .x = 1, .y = 0 },       .{ .x = 0xFF, .y = 1 },
    .{ .x = 0, .y = 1 },       .{ .x = 1, .y = 1 },
};
fn countNeighborWall(tiles: []Tile, x: u8, y: u8) u8 {
    var count: u8 = 0;
    for (&neighborDir) |dir| {
        const dx, const dy = .{ x +% dir.x, y +% dir.y };
        if (tiles[dy * WIDTH + dx] == .wall) count += 1;
    }
    return count;
}

fn spawnRandomMonster(tiles: []Tile) TilePosition {
    var roll = zhu.randomInt(u16, 0, HEIGHT * WIDTH);
    while (tiles[roll] == .wall) {
        roll = zhu.randomInt(u16, 0, HEIGHT * WIDTH);
    }
    const x, const y = .{ roll % WIDTH, roll / WIDTH };
    return .{ .x = @intCast(x), .y = @intCast(y) };
}

pub fn indexUsize(x: usize, y: usize) usize {
    return @min(x, WIDTH - 1) + @min(y, HEIGHT - 1) * WIDTH;
}

fn setTile(tiles: []Tile, x: usize, y: usize, tile: Tile) void {
    tiles[indexUsize(x, y)] = tile;
}
