const std = @import("std");
const engine = @import("engine.zig");

pub const TileType = enum(u8) {
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

pub const Map = struct {
    const WIDTH: usize = 80;
    const HEIGHT: usize = 50;
    const NUM_TILES: usize = WIDTH * HEIGHT;
    const NUM_ROOMS: usize = 20;

    tiles: [NUM_TILES]TileType = .{.wall} ** NUM_TILES,
    sheet: engine.SpriteSheet,
    rooms: [NUM_ROOMS]engine.Rect = undefined,

    pub fn init(texture: engine.Texture) Map {
        var map = Map{ .sheet = engine.SpriteSheet.init(texture, 32) };
        map.buildRooms();
        std.mem.sort(engine.Rect, &map.rooms, {}, Map.compare);
        map.buildCorridors();
        return map;
    }

    pub fn compare(_: void, r1: engine.Rect, r2: engine.Rect) bool {
        return if (r1.x == r2.x) r1.y < r2.y else r1.x < r2.x;
    }

    fn buildRooms(self: *Map) void {
        for (0..self.rooms.len) |roomIndex| {
            var room = engine.Rect{};
            label: {
                room = engine.Rect{
                    .x = engine.randomValue(1, WIDTH - 10),
                    .y = engine.randomValue(1, HEIGHT - 10),
                    .width = engine.randomValue(2, 10),
                    .height = engine.randomValue(2, 10),
                };

                for (0..roomIndex) |idx| {
                    if (self.rooms[idx].intersect(room)) break :label;
                }
            }

            for (room.y..room.y + room.height) |y| {
                for (room.x..room.x + room.width) |x| {
                    self.setTile(x, y, .floor);
                }
            }
            self.rooms[roomIndex] = room;
        }
    }

    fn applyVertical(self: *Map, y1: usize, y2: usize, x: usize) void {
        for (@min(y1, y2)..@max(y1, y2) + 1) |y| {
            self.setTile(x, y, .floor);
        }
    }

    fn applyHorizontal(self: *Map, x1: usize, x2: usize, y: usize) void {
        for (@min(x1, x2)..@max(x1, x2) + 1) |x| {
            self.setTile(x, y, .floor);
        }
    }

    fn buildCorridors(self: *Map) void {
        for (self.rooms[1..], 1..) |room, roomIndex| {
            const prev = self.rooms[roomIndex - 1].center();
            const new = room.center();
            if (engine.randomValue(0, 2) == 1) {
                self.applyHorizontal(prev.x, new.x, prev.y);
                self.applyVertical(prev.y, new.y, new.x);
            } else {
                self.applyVertical(prev.y, new.y, prev.x);
                self.applyHorizontal(prev.x, new.x, new.y);
            }
        }
    }

    fn indexUsize(x: usize, y: usize) usize {
        const x1 = if (x < WIDTH) x else WIDTH - 1;
        const y1 = if (y < HEIGHT) y else HEIGHT - 1;
        return x1 + y1 * WIDTH;
    }

    pub fn setTile(self: *Map, x: usize, y: usize, tile: TileType) void {
        self.tiles[indexUsize(x, y)] = tile;
    }

    pub fn indexTile(self: Map, x: usize, y: usize) TileType {
        return self.tiles[indexUsize(x, y)];
    }

    pub fn canEnter(self: Map, player: engine.Vec) bool {
        return player.x < WIDTH and player.y < HEIGHT //
        and self.indexTile(player.x, player.y) == .floor;
    }
};

pub const Camera = struct {
    x: usize,
    y: usize,
    width: usize,
    height: usize,

    pub fn init(x: usize, y: usize) Camera {
        // const screenSize = engine.getScreenSize();
        return .{
            .x = x -| (40 / 2),
            .y = y -| (25 / 2),
            .width = 40,
            .height = 25,
        };
    }

    pub fn isVisible(self: Camera, vec: engine.Vec) bool {
        return vec.x >= self.x and vec.y >= self.y and //
            vec.x < self.x + self.width and vec.y < self.y + self.height;
    }
};
