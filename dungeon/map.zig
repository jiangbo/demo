const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const camera = zhu.camera;

const Tile = enum(u8) {
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

const Rect = struct { x: u8, y: u8, w: u8, h: u8 };
const Vec = struct { x: u8, y: u8 };

const WIDTH = 80;
const HEIGHT = 50;
const NUM_ROOMS = 20;
const TILE_SIZE: gfx.Vector = .init(32, 32);
const TILE_PER_ROW = 16;
const SCALE = 0.2;

var tiles: [WIDTH * HEIGHT]Tile = undefined;
var vertexBuffer: [tiles.len]camera.Vertex = undefined;
var texture: gfx.Texture = undefined;
var rooms: [NUM_ROOMS]Rect = undefined;

pub fn init() void {
    texture = gfx.loadTexture("assets/dungeonfont.png", .init(512, 512));

    @memset(&tiles, .wall);
    buildRooms();
    std.mem.sort(Rect, &rooms, {}, compare);
    buildCorridors();

    initVertexBuffer();
}

fn initVertexBuffer() void {
    var array: std.ArrayList(camera.Vertex) = .initBuffer(&vertexBuffer);
    for (tiles, 0..) |tileIndex, index| {
        const tile: u8 = @intFromEnum(tileIndex);
        array.appendAssumeCapacity(buildVertex(tile, index));
    }
}

fn buildVertex(tileIndex: usize, index: usize) camera.Vertex {
    const row: f32 = @floatFromInt(tileIndex / TILE_PER_ROW);
    const col: f32 = @floatFromInt(tileIndex % TILE_PER_ROW);

    const pos = gfx.Vector.init(col, row).mul(TILE_SIZE);

    const tile = texture.subTexture(.init(pos, TILE_SIZE));
    return camera.Vertex{
        .position = getPositionFromIndex(index).toVector3(0),
        .size = TILE_SIZE.scale(SCALE),
        .texture = tile.area.toVector4(),
    };
}

fn getPositionFromIndex(index: usize) gfx.Vector {
    const row: f32 = @floatFromInt(index / WIDTH);
    const col: f32 = @floatFromInt(index % WIDTH);
    return gfx.Vector.init(col, row).mul(TILE_SIZE.scale(SCALE));
}

fn buildRooms() void {
    for (0..rooms.len) |roomIndex| {
        var room: Rect = undefined;
        label: {
            room = Rect{
                .x = zhu.randU8(1, WIDTH - 10),
                .y = zhu.randU8(1, HEIGHT - 10),
                .w = zhu.randU8(2, 10),
                .h = zhu.randU8(2, 10),
            };

            for (0..roomIndex) |idx| {
                if (intersect(rooms[idx], room)) break :label;
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

fn intersect(r1: Rect, r2: Rect) bool {
    return r1.x < r2.x + r2.w and r1.x + r1.w > r2.x and
        r1.y < r2.y + r2.h and r1.y + r1.h > r2.y;
}

fn center(r: Rect) Vec {
    return Vec{ .x = r.x + r.w / 2, .y = r.y + r.h / 2 };
}

fn compare(_: void, r1: Rect, r2: Rect) bool {
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
        const prev = center(rooms[roomIndex - 1]);
        const new = center(room);
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

pub fn canEnter(player: zhu.math.Vector2) bool {
    return player.x < WIDTH and player.y < HEIGHT //
    and indexTile(player.x, player.y) == .floor;
}

pub fn draw() void {
    camera.drawVertices(texture, &vertexBuffer);
}
