const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const tiled = zhu.extend.tiled;

const Land = @This();

map: *const tiled.Map = undefined,
tiles: []Tile = &.{},

const Object = struct {
    kind: enum { crop, product, chest } = .crop,
    entity: zhu.ecs.Entity,
};

pub const Tile = struct {
    ground: ?component.farm.Ground = null,
    object: ?Object = null,
    gone: enum { none, product } = .none,

    pub fn crop(self: Tile) ?zhu.ecs.Entity {
        const object = self.object orelse return null;
        if (object.kind != .crop) return null;
        return object.entity;
    }

    pub fn product(self: Tile) ?zhu.ecs.Entity {
        const object = self.object orelse return null;
        if (object.kind != .product) return null;
        return object.entity;
    }

    pub fn setProduct(self: *Tile, entity: zhu.ecs.Entity) void {
        self.object = .{ .kind = .product, .entity = entity };
    }
};

pub fn init(gpa: zhu.Allocator, mapData: *const tiled.Map) Land {
    var self = Land{ .map = mapData };

    self.tiles = gpa.alloc(Tile, self.map.width * self.map.height);
    @memset(self.tiles, .{});

    return self;
}

pub fn deinit(self: *Land, gpa: zhu.Allocator) void {
    gpa.free(self.tiles);
}

pub fn getTile(self: Land, position: zhu.Vector2) ?*Tile {
    std.debug.assert(self.tiles.len != 0);
    const tile = self.map.worldToTilePosition(position);
    if (tile.x < 0 or tile.y < 0) return null;

    const width: i32 = @intCast(self.map.width);
    const height: i32 = @intCast(self.map.height);
    if (tile.x >= width or tile.y >= height) return null;

    return &self.tiles[@as(usize, @intCast(tile.y * width + tile.x))];
}

pub fn canHoe(self: Land, position: zhu.Vector2) bool {
    const tile = self.getTile(position) orelse return false;
    if (tile.ground != null) return false;
    if (tile.object != null) return false;
    return true;
}

pub fn canPlant(self: Land, position: zhu.Vector2) bool {
    const tile = self.getTile(position) orelse return false;
    if (tile.ground == null) return false;
    if (tile.object != null) return false;
    return true;
}

pub fn hoe(self: *Land, position: zhu.Vector2) bool {
    if (!self.canHoe(position)) return false;
    const tile = self.getTile(position).?;
    tile.ground = .dry;
    return true;
}

pub fn water(self: *Land, position: zhu.Vector2) bool {
    const tile = self.getTile(position) orelse return false;
    if (tile.ground == null) return false;
    tile.ground = .wet;
    return true;
}

pub fn draw(self: Land, dry: zhu.Image, wet: zhu.Image) void {
    for (self.tiles, 0..) |tile, index| {
        const ground = tile.ground orelse continue;
        const position = self.map.tileIndexToWorld(index);
        appendVertex(position, dry);
        if (ground == .wet) appendVertex(position, wet);
    }
}

fn appendVertex(position: zhu.Vector2, image: zhu.Image) void {
    zhu.batch.vertices.appendAssumeCapacity(.{
        .position = position,
        .layer = image.layer,
        .size = image.size,
        .uvRect = image.uvRect(),
    });
}

test "锄地会记录目标格" {
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    var land = Land.init(zhu.testing.allocator, &testMaps[0]);
    defer land.deinit(zhu.testing.allocator);

    try std.testing.expect(land.hoe(.xy(32, 48)));

    try std.testing.expectEqual(.dry, land.getTile(.xy(32, 48)).?.ground);
}

test "浇水只会影响已有耕地" {
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    var land = Land.init(zhu.testing.allocator, &testMaps[0]);
    defer land.deinit(zhu.testing.allocator);

    try std.testing.expect(!land.water(.xy(32, 48)));
    try std.testing.expectEqual(null, land.getTile(.xy(32, 48)).?.ground);

    try std.testing.expect(land.hoe(.xy(32, 48)));
    try std.testing.expect(land.water(.xy(32, 48)));
    try std.testing.expectEqual(.wet, land.getTile(.xy(32, 48)).?.ground);
}

test "目标格有作物时不会锄地" {
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    var land = Land.init(zhu.testing.allocator, &testMaps[0]);
    defer land.deinit(zhu.testing.allocator);

    land.getTile(.xy(32, 48)).?.object = .{ .entity = 1 };

    try std.testing.expect(!land.hoe(.xy(32, 48)));
    try std.testing.expectEqual(null, land.getTile(.xy(32, 48)).?.ground);
}

test "锄地要求地块为空" {
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    var land = Land.init(zhu.testing.allocator, &testMaps[0]);
    defer land.deinit(zhu.testing.allocator);

    const position = zhu.Vector2.xy(32, 48);

    try std.testing.expect(land.canHoe(position));

    land.getTile(position).?.ground = .dry;
    try std.testing.expect(!land.canHoe(position));

    land.getTile(position).?.ground = null;
    land.getTile(position).?.object = .{ .entity = 1 };
    try std.testing.expect(!land.canHoe(position));
}

test "种植只要求已有耕地且没有对象" {
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    var land = Land.init(zhu.testing.allocator, &testMaps[0]);
    defer land.deinit(zhu.testing.allocator);

    const position = zhu.Vector2.xy(32, 48);
    const tile = land.getTile(position).?;

    try std.testing.expect(!land.canPlant(position));

    tile.ground = .dry;
    try std.testing.expect(land.canPlant(position));

    tile.object = .{ .entity = 1 };
    try std.testing.expect(!land.canPlant(position));
}

test "浇水要求已有耕地" {
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    var land = Land.init(zhu.testing.allocator, &testMaps[0]);
    defer land.deinit(zhu.testing.allocator);

    const position = zhu.Vector2.xy(32, 48);
    const tile = land.getTile(position).?;

    try std.testing.expect(!land.water(position));

    tile.ground = .dry;
    try std.testing.expect(land.water(position));
    try std.testing.expectEqual(.wet, tile.ground.?);

    tile.object = .{ .entity = 1 };
    try std.testing.expect(land.water(position));
}
