const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const camera = zhu.camera;
const ecs = zhu.ecs;
const window = zhu.window;

const component = @import("component.zig");
const builder = @import("builder.zig");

const Position = component.Position;
const TilePosition = component.TilePosition;
const TileRect = component.TileRect;
const WantToMove = component.WantToMove;
const Player = component.Player;

pub const Tile = component.Tile;
pub const ViewField = component.ViewField;

const WIDTH = builder.WIDTH;
const HEIGHT = builder.HEIGHT;
pub const TILE_SIZE: gfx.Vector = .init(32, 32);
const TILE_PER_ROW = 16;

pub var size = gfx.Vector.init(WIDTH, HEIGHT).mul(TILE_SIZE);
var tiles: [WIDTH * HEIGHT]Tile = undefined;
var texture: gfx.Texture = undefined;
pub var rooms: [20]TileRect = undefined;
var walks: [HEIGHT * WIDTH]bool = undefined;

pub fn init() void {
    texture = gfx.loadTexture("assets/dungeonfont.png", .init(512, 512));

    @memset(&tiles, .wall);
    builder.buildRooms(&tiles, &rooms);
    std.mem.sort(TileRect, &rooms, {}, compare);
    builder.buildCorridors(&tiles, &rooms);

    builder.updateDistance(&tiles, rooms[0].center());
    @memset(&walks, false);
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

fn compare(_: void, r1: TileRect, r2: TileRect) bool {
    return if (r1.x == r2.x) r1.y < r2.y else r1.x < r2.x;
}

const indexUsize = builder.indexUsize;
pub fn indexTile(x: usize, y: usize) Tile {
    return tiles[indexUsize(x, y)];
}

pub fn worldPosition(pos: TilePosition) Position {
    return pos.toVector().mul(TILE_SIZE);
}

pub fn canMove(pos: TilePosition) bool {
    return pos.x < WIDTH and pos.y < HEIGHT //
    and indexTile(pos.x, pos.y) == .floor;
}

pub fn moveIfNeed() void {
    var view = ecs.w.view(.{ WantToMove, TilePosition });
    blk: while (view.next()) |entity| {
        const dest = view.get(entity, WantToMove)[0];
        if (!canMove(dest)) continue;

        for (ecs.w.raw(TilePosition)) |pos| {
            if (pos.equals(dest)) continue :blk;
        }

        view.getPtr(entity, TilePosition).* = dest;
        const pos = worldPosition(dest);
        view.getPtr(entity, Position).* = pos;
    }
}

pub const queryLessDistance = builder.queryLessDistance;
pub fn updateDistance(pos: TilePosition) void {
    builder.updateDistance(&tiles, pos);
}

pub fn updatePlayerWalk() void {
    const viewField = ecs.w.getIdentity(Player, ViewField).?[0];

    for (viewField.y..viewField.y + viewField.h) |y| {
        const start = indexUsize(viewField.x, y);
        @memset(walks[start..][0..viewField.w], true);
    }
}

pub fn draw() void {
    drawPlayerWalk();
    drawPlayerView();
}

fn drawPlayerWalk() void {
    const playerEntity = ecs.w.getIdentityEntity(Player).?;
    const viewField = ecs.w.get(playerEntity, ViewField).?[0];
    const playerPos = ecs.w.get(playerEntity, TilePosition).?;

    const x = playerPos.x -| 10;
    const y = playerPos.y -| 7;
    const windowView = TileRect{ .x = x, .y = y, .w = 20, .h = 13 };

    for (walks, 0..) |isWalk, index| {
        if (!isWalk) continue;
        const pos = TilePosition{
            .x = @intCast(index % WIDTH),
            .y = @intCast(index / WIDTH),
        };
        if (!windowView.contains(pos)) continue;
        if (viewField.contains(pos)) continue;

        const tex = getTextureFromTile(tiles[index]);
        camera.drawOption(tex, getPositionFromIndex(index), .{
            .color = .{ .x = 0.5, .y = 0.5, .z = 0.5, .w = 1 },
        });
    }
}

fn drawPlayerView() void {
    const viewField = ecs.w.getIdentity(Player, ViewField).?[0];

    for (viewField.x..viewField.x + viewField.w) |x| {
        for (viewField.y..viewField.y + viewField.h) |y| {
            const index = indexUsize(x, y);
            const tex = getTextureFromTile(tiles[index]);
            camera.draw(tex, getPositionFromIndex(index));
        }
    }
}
