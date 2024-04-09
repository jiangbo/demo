const std = @import("std");
const engine = @import("engine.zig");

const SCREEN_WIDTH: usize = 80;
const SCREEN_HEIGHT: usize = 50;
const NUM_TILES: usize = SCREEN_WIDTH * SCREEN_HEIGHT;
const NUM_ROOMS: usize = 20;
pub const SIZE = 32;

pub const DISPLAY_WIDTH: usize = SCREEN_WIDTH / 2;
pub const DISPLAY_HEIGHT: usize = SCREEN_HEIGHT / 2;

pub const Rect = struct {
    x: usize = 0,
    y: usize = 0,
    width: usize = 0,
    height: usize = 0,

    pub fn init(x: usize, y: usize, width: usize, height: usize) Rect {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    pub fn intersect(self: Rect, other: Rect) bool {
        return (self.x <= other.x + other.width //
        and self.x + self.width >= other.x //
        and self.y <= self.y + self.height //
        and self.y + self.height >= other.y);
    }

    pub fn center(self: Rect) Vec2 {
        return Vec2{
            .x = (self.x + self.x + self.width) / 2,
            .y = (self.y + self.y + self.height) / 2,
        };
    }

    pub fn compare(_: void, self: Rect, r2: Rect) bool {
        if (self.x == r2.x) return self.y < r2.y;
        return self.x < r2.x;
    }
};

pub const TileType = enum(u8) {
    wall = 35,
    floor = 46,
    player = 64,
};

pub const Camera = Rect;

pub const MapBuilder = struct {
    map: Map,
    rooms: [NUM_ROOMS]Rect = undefined,
    player: Vec2 = Vec2{},
    camera: Camera = Rect{},

    pub fn init() MapBuilder {
        var builder = MapBuilder{ .map = Map.init() };
        builder.buildRooms();
        std.mem.sort(Rect, &builder.rooms, {}, Rect.compare);
        builder.buildCorridors();
        builder.player = builder.rooms[0].center();
        builder.camera = buildCamera(builder.player);
        return builder;
    }

    fn buildCamera(player: Vec2) Camera {
        return Camera{
            .x = player.x -| (DISPLAY_WIDTH / 2),
            .y = player.y -| (DISPLAY_HEIGHT / 2),
            .width = DISPLAY_WIDTH,
            .height = DISPLAY_HEIGHT,
        };
    }

    pub fn render(self: MapBuilder) void {
        self.map.render(self.camera);
        const index = @intFromEnum(TileType.player);
        const x = self.player.x -| self.camera.x;
        const y = self.player.y -| self.camera.y;
        self.map.tilemap.drawTile(index, x, y);
    }

    pub fn update(self: *MapBuilder) void {
        var player = self.player;
        if (ray.IsKeyPressed(ray.KEY_A)) player.x -|= 1;
        if (ray.IsKeyPressed(ray.KEY_S)) player.y += 1;
        if (ray.IsKeyPressed(ray.KEY_D)) player.x += 1;
        if (ray.IsKeyPressed(ray.KEY_W)) player.y -|= 1;

        if (!self.map.canEnter(player)) return;
        self.player = player;
        self.camera = buildCamera(player);
    }
};

pub const Map = struct {
    tiles: [NUM_TILES]TileType = .{.wall} ** NUM_TILES,
    tilemap: Tilemap,

    pub fn init() Map {
        return Map{ .tilemap = Tilemap.init() };
    }

    pub fn setTile(self: *Map, x: usize, y: usize, tile: TileType) void {
        self.tiles[index(x, y)] = tile;
    }

    pub fn canEnter(self: Map, player: Vec2) bool {
        return player.x < SCREEN_WIDTH and player.y < SCREEN_HEIGHT //
        and self.indexTile(player.x, player.y) == .floor;
    }

    fn index(x: usize, y: usize) usize {
        const x1 = if (x < SCREEN_WIDTH) x else SCREEN_WIDTH - 1;
        const y1 = if (y < SCREEN_HEIGHT) y else SCREEN_HEIGHT - 1;
        return x1 + y1 * SCREEN_WIDTH;
    }

    pub fn indexTile(self: Map, x: usize, y: usize) TileType {
        return self.tiles[index(x, y)];
    }

    pub fn render(self: Map, camera: Camera) void {
        for (0..camera.height) |y| {
            for (0..camera.width) |x| {
                const tile = self.indexTile(x + camera.x, y + camera.y);
                self.tilemap.drawTile(@intFromEnum(tile), x, y);
            }
        }

        // for (0..SCREEN_HEIGHT) |y| {
        //     for (0..SCREEN_WIDTH) |x| {
        //         const idx = @intFromEnum(self.tiles[index(x, y)]);
        //         self.tilemap.drawTile(idx, x, y);
        //     }
        // }
    }
};
