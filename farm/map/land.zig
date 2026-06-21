const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const spatial = @import("spatial.zig");
const tiled = zhu.extend.tiled;

var map: *const tiled.Map = undefined;
pub var tiles: []Tile = &.{};

var dryImage: zhu.graphics.Image = undefined;
var wetImage: zhu.graphics.Image = undefined;

const Object = struct {
    kind: enum { crop, rock, chest } = .crop,
    entity: zhu.ecs.Entity,
};

pub const Tile = struct {
    ground: ?component.farm.Ground = null,
    object: ?Object = null,

    pub fn crop(self: Tile) ?zhu.ecs.Entity {
        const object = self.object orelse return null;
        if (object.kind != .crop) return null;
        return object.entity;
    }
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

fn canHoe(position: zhu.Vector2) bool {
    if (!spatial.canHoeTile(position)) return false;

    const tile = getTile(position) orelse return false;
    if (tile.ground != null) return false;
    if (tile.object != null) return false;
    return true;
}

pub fn canPlant(position: zhu.Vector2) bool {
    const tile = getTile(position) orelse return false;
    if (tile.ground == null) return false;
    if (tile.object != null) return false;
    return true;
}

fn canWater(position: zhu.Vector2) bool {
    const tile = getTile(position) orelse return false;
    return tile.ground != null;
}

pub fn hoe(position: zhu.Vector2) bool {
    if (!canHoe(position)) return false;
    const tile = getTile(position).?;
    tile.ground = .dry;
    return true;
}

pub fn water(position: zhu.Vector2) bool {
    if (!canWater(position)) return false;
    const tile = getTile(position).?;
    tile.ground = .wet;
    return true;
}

pub fn draw() void {
    for (tiles, 0..) |tile, index| {
        const ground = tile.ground orelse continue;
        const position = map.tileIndexToWorld(index);
        appendVertex(position, dryImage);
        if (ground == .wet) appendVertex(position, wetImage);
    }
}

fn appendVertex(position: zhu.Vector2, image: zhu.Image) void {
    zhu.batch.vertices.appendAssumeCapacity(.{
        .position = position,
        .size = image.size,
        .uvRect = image.uvRect(),
    });
}

test "锄地会记录目标格" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    spatial.enter(&testMaps[0]);
    defer spatial.exit();
    enter(&testMaps[0]);
    defer exit();

    spatial.tiles[spatialIndex(.xy(32, 48))].insert(.arable);

    try std.testing.expect(hoe(.xy(32, 48)));

    try std.testing.expectEqual(.dry, getTile(.xy(32, 48)).?.ground);
}

test "浇水只会影响已有耕地" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    spatial.enter(&testMaps[0]);
    defer spatial.exit();
    enter(&testMaps[0]);
    defer exit();

    spatial.tiles[spatialIndex(.xy(32, 48))].insert(.arable);

    try std.testing.expect(!water(.xy(32, 48)));
    try std.testing.expectEqual(null, getTile(.xy(32, 48)).?.ground);

    try std.testing.expect(hoe(.xy(32, 48)));
    try std.testing.expect(water(.xy(32, 48)));
    try std.testing.expectEqual(.wet, getTile(.xy(32, 48)).?.ground);
}

test "目标格有作物时不会锄地" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    spatial.enter(&testMaps[0]);
    defer spatial.exit();
    enter(&testMaps[0]);
    defer exit();

    spatial.tiles[spatialIndex(.xy(32, 48))].insert(.arable);
    getTile(.xy(32, 48)).?.object = .{ .entity = 1 };

    try std.testing.expect(!hoe(.xy(32, 48)));
    try std.testing.expectEqual(null, getTile(.xy(32, 48)).?.ground);
}

test "锄地要求地图语义可耕作且不被阻挡" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    spatial.enter(&testMaps[0]);
    defer spatial.exit();
    enter(&testMaps[0]);
    defer exit();

    const position = zhu.Vector2.xy(32, 48);
    const index = spatialIndex(position);

    try std.testing.expect(!canHoe(position));

    spatial.tiles[index].insert(.arable);
    try std.testing.expect(canHoe(position));

    spatial.tiles[index].insert(.water);
    try std.testing.expect(!canHoe(position));
    spatial.tiles[index].remove(.water);

    spatial.tiles[index].insert(.occupied);
    try std.testing.expect(!canHoe(position));
    spatial.tiles[index].remove(.occupied);

    spatial.tiles[index].insert(.north);
    try std.testing.expect(!canHoe(position));
}

test "种植只要求已有耕地且没有对象" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    spatial.enter(&testMaps[0]);
    defer spatial.exit();
    enter(&testMaps[0]);
    defer exit();

    const position = zhu.Vector2.xy(32, 48);
    const tile = getTile(position).?;

    try std.testing.expect(!canPlant(position));

    tile.ground = .dry;
    try std.testing.expect(canPlant(position));

    tile.object = .{ .entity = 1 };
    try std.testing.expect(!canPlant(position));
}

test "浇水只要求已有耕地" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    spatial.enter(&testMaps[0]);
    defer spatial.exit();
    enter(&testMaps[0]);
    defer exit();

    const position = zhu.Vector2.xy(32, 48);
    const tile = getTile(position).?;

    try std.testing.expect(!canWater(position));

    tile.ground = .dry;
    try std.testing.expect(canWater(position));

    tile.object = .{ .entity = 1 };
    try std.testing.expect(canWater(position));
}

fn spatialIndex(position: zhu.Vector2) usize {
    const tile = map.worldToTilePosition(position);
    const width: i32 = @intCast(map.width);
    return @intCast(tile.y * width + tile.x);
}
