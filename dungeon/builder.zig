const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");

const TileRect = component.TileRect;
const Tile = component.Tile;

pub const WIDTH = 80;
pub const HEIGHT = 50;

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

fn indexUsize(x: usize, y: usize) usize {
    const x1 = if (x < WIDTH) x else WIDTH - 1;
    const y1 = if (y < HEIGHT) y else HEIGHT - 1;
    return x1 + y1 * WIDTH;
}

pub fn setTile(tiles: []Tile, x: usize, y: usize, tile: Tile) void {
    tiles[indexUsize(x, y)] = tile;
}
