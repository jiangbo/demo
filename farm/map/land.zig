const std = @import("std");
const zhu = @import("zhu");

const tiled = zhu.extend.tiled;

var map: *const tiled.Map = undefined;
pub var tiles: []Tile = &.{};

var dryImage: zhu.graphics.Image = undefined;
var wetImage: zhu.graphics.Image = undefined;

pub const Tile = struct {
    land: ?enum { dry, wet } = null,
    crop: ?zhu.ecs.Entity = null,
};

pub fn init() void {
    const path = "farm-rpg/Farm/Tileset/Modular/Tilled Soil and wet soil.png";
    const image = zhu.getImage(path).?;
    dryImage = image.sub(.init(.xy(0, 48), .xy(16, 16)));
    wetImage = image.sub(.init(.xy(192, 48), .xy(16, 16)));
}

pub fn enter(mapData: *const tiled.Map) void {
    exit();

    map = mapData;
    tiles = zhu.assets.oomAlloc(Tile, map.width * map.height);
    @memset(tiles, .{});
}

pub fn exit() void {
    if (tiles.len > 0) zhu.assets.free(tiles);
    tiles = &.{};
}

pub fn deinit() void {
    exit();
}

pub fn getTile(position: zhu.Vector2) ?*Tile {
    std.debug.assert(tiles.len != 0);
    const tile = map.worldToTilePosition(position);
    if (tile.x < 0 or tile.y < 0) return null;

    const width: i32 = @intCast(map.width);
    const height: i32 = @intCast(map.height);
    if (tile.x >= width or tile.y >= height) return null;

    return &tiles[@as(usize, @intCast(tile.y * width + tile.x))];
}

pub fn hoe(position: zhu.Vector2) void {
    const tile = getTile(position) orelse return;
    if (tile.land != null or tile.crop != null) return;
    tile.land = .dry;
}

pub fn water(position: zhu.Vector2) void {
    const tile = getTile(position) orelse return;
    if (tile.land == null) return;
    tile.land = .wet;
}

pub fn draw() void {
    for (tiles, 0..) |tile, index| {
        const land = tile.land orelse continue;
        const position = map.tileIndexToWorld(index);
        appendVertex(position, dryImage);
        if (land == .wet) appendVertex(position, wetImage);
    }
}

fn appendVertex(position: zhu.Vector2, image: zhu.Image) void {
    zhu.batch.vertexBuffer.appendAssumeCapacity(.{
        .position = position,
        .size = image.size,
        .uvRect = image.toUvRect(),
    });
}

test "锄地会记录目标格" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/school.zon")};
    enter(&testMaps[0]);
    defer exit();

    hoe(.xy(32, 48));

    try std.testing.expectEqual(.dry, getTile(.xy(32, 48)).?.land);
}

test "浇水只会影响已有耕地" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/school.zon")};
    enter(&testMaps[0]);
    defer exit();

    water(.xy(32, 48));
    try std.testing.expectEqual(null, getTile(.xy(32, 48)).?.land);

    hoe(.xy(32, 48));
    water(.xy(32, 48));
    try std.testing.expectEqual(.wet, getTile(.xy(32, 48)).?.land);
}

test "目标格有作物时不会锄地" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/school.zon")};
    enter(&testMaps[0]);
    defer exit();

    getTile(.xy(32, 48)).?.crop = 1;

    hoe(.xy(32, 48));
    try std.testing.expectEqual(null, getTile(.xy(32, 48)).?.land);
}
