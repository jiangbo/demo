const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const camera = zhu.camera;
const ecs = zhu.ecs;
const window = zhu.window;

const component = @import("component.zig");

const Position = component.Position;
const TilePosition = component.TilePosition;
const TileRect = component.TileRect;
const WantToMove = component.WantToMove;

pub const Tile = enum(u8) {
    other = 0,
    wall = 35,
    floor = 46,
    player = 64,
    ettin = 69,
    ogre = 79,
    goblin = 103,
    orc = 111,
    amulet = 124,
};

const WIDTH = 80;
const HEIGHT = 50;
const NUM_ROOMS = 20;
pub const TILE_SIZE: gfx.Vector = .init(32, 32);
const TILE_PER_ROW = 16;

pub var size = gfx.Vector.init(WIDTH, HEIGHT).mul(TILE_SIZE);
var tiles: [WIDTH * HEIGHT]Tile = undefined;
var vertexBuffer: [tiles.len]camera.Vertex = undefined;
var texture: gfx.Texture = undefined;
pub var rooms: [NUM_ROOMS]TileRect = undefined;
var distances: [WIDTH * HEIGHT]u8 = undefined;

pub fn init() void {
    texture = gfx.loadTexture("assets/dungeonfont.png", .init(512, 512));

    @memset(&tiles, .wall);
    buildRooms();
    std.mem.sort(TileRect, &rooms, {}, compare);
    buildCorridors();

    updateDistance(rooms[0].center());

    initVertexBuffer();
}

fn initVertexBuffer() void {
    var array: std.ArrayList(camera.Vertex) = .initBuffer(&vertexBuffer);
    for (tiles, 0..) |tile, index| {
        const tex = getTextureFromTile(tile);
        const pos = getPositionFromIndex(index);
        array.appendAssumeCapacity(.{
            .position = pos.toVector3(0),
            .size = TILE_SIZE,
            .texture = tex.area.toVector4(),
        });
    }
}

pub fn getTextureFromTile(tile: Tile) gfx.Texture {
    const index: usize = @intFromEnum(tile);
    const row: f32 = @floatFromInt(index / TILE_PER_ROW);
    const col: f32 = @floatFromInt(index % TILE_PER_ROW);
    const pos = gfx.Vector.init(col, row).mul(TILE_SIZE);
    return texture.subTexture(.init(pos, TILE_SIZE));
}

fn getPositionFromIndex(index: usize) gfx.Vector {
    const row: f32 = @floatFromInt(index / WIDTH);
    const col: f32 = @floatFromInt(index % WIDTH);
    return gfx.Vector.init(col, row).mul(TILE_SIZE);
}

fn buildRooms() void {
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
                setTile(x, y, .floor);
            }
        }
        rooms[roomIndex] = room;
    }
}

fn compare(_: void, r1: TileRect, r2: TileRect) bool {
    return if (r1.x == r2.x) r1.y < r2.y else r1.x < r2.x;
}

fn applyVertical(y1: usize, y2: usize, x: usize) void {
    for (@min(y1, y2)..@max(y1, y2) + 1) |y| {
        setTile(x, y, .floor);
    }
}

fn applyHorizontal(x1: usize, x2: usize, y: usize) void {
    for (@min(x1, x2)..@max(x1, x2) + 1) |x| {
        setTile(x, y, .floor);
    }
}

fn buildCorridors() void {
    for (rooms[1..], 1..) |room, roomIndex| {
        const prev = rooms[roomIndex - 1].center();
        const new = room.center();
        if (zhu.randU8(0, 2) == 1) {
            applyHorizontal(prev.x, new.x, prev.y);
            applyVertical(prev.y, new.y, new.x);
        } else {
            applyVertical(prev.y, new.y, prev.x);
            applyHorizontal(prev.x, new.x, new.y);
        }
    }
}

fn indexUsize(x: usize, y: usize) usize {
    const x1 = if (x < WIDTH) x else WIDTH - 1;
    const y1 = if (y < HEIGHT) y else HEIGHT - 1;
    return x1 + y1 * WIDTH;
}

pub fn setTile(x: usize, y: usize, tile: Tile) void {
    tiles[indexUsize(x, y)] = tile;
}

pub fn indexTile(x: usize, y: usize) Tile {
    return tiles[indexUsize(x, y)];
}

pub fn worldPosition(pos: TilePosition) Position {
    return getPositionFromIndex(indexUsize(pos.x, pos.y));
}

const directions: [4]isize = .{ 1, -1, WIDTH, -WIDTH };
pub fn updateDistance(pos: TilePosition) void {
    @memset(&distances, 0xFF);

    var queue = std.PriorityDequeue(usize, void, struct {
        fn compare(_: void, a: usize, b: usize) std.math.Order {
            return std.math.order(distances[a], distances[b]);
        }
    }.compare).init(window.allocator, {});
    defer queue.deinit();

    var max: u8 = 0;
    queue.add(indexUsize(pos.x, pos.y)) catch unreachable;
    distances[indexUsize(pos.x, pos.y)] = max;

    while (queue.removeMinOrNull()) |min| {
        const distance = distances[min];

        for (directions) |dir| {
            const offset = @as(isize, @intCast(min)) + dir;
            if (offset < 0 or offset >= distances.len) continue; // 超过地图

            const index: usize = @intCast(offset);
            if (dir == 1 and index % WIDTH == 0) continue; // 换行
            if (dir == -1 and index % WIDTH == WIDTH - 1) continue;
            if (tiles[index] != .floor) continue; // 不可通过

            if (distance + 1 < distances[index]) {
                distances[index] = distance + 1;
                queue.add(index) catch unreachable;
                max = @max(max, distances[index]);
            }
        }
    }

    std.log.info("max distance: {}", .{max});
}

pub fn queryLessDistance(pos: TilePosition) ?TilePosition {
    const i: usize = indexUsize(pos.x, pos.y);
    const distance = distances[i];
    if (distance == 0) return null;

    var result: ?TilePosition = null;
    for (directions) |dir| {
        const offset = @as(isize, @intCast(i)) + dir;

        if (offset < 0 or offset >= distances.len) continue; // 超过地图

        const index: usize = @intCast(offset);
        if (dir == 1 and index % WIDTH == 0) continue; // 换行
        if (dir == -1 and index % WIDTH == WIDTH - 1) continue;
        if (distances[index] < distance) {
            result = .{
                .x = @intCast(index % WIDTH),
                .y = @intCast(index / WIDTH),
            };
        }
    }

    return result;
}

pub fn update(_: f32) void {
    moveIfNeed();
}

fn moveIfNeed() void {
    var view = ecs.w.view(.{ WantToMove, TilePosition });
    blk: while (view.next()) |entity| {
        const dest = view.get(entity, WantToMove)[0];
        const canMove = dest.x < WIDTH and dest.y < HEIGHT //
        and indexTile(dest.x, dest.y) == .floor;
        if (!canMove) continue;

        for (ecs.w.raw(TilePosition)) |pos| {
            if (pos.equals(dest)) continue :blk;
        }

        view.getPtr(entity, TilePosition).* = dest;
        const pos = worldPosition(dest);
        view.getPtr(entity, Position).* = pos;
    }
}

pub fn draw() void {
    camera.drawVertices(texture, &vertexBuffer);
}
