const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");

const tiled = zhu.extend.tiled;
const Position = component.Position;
const Shape = component.motion.Shape;
const Blocking = component.motion.Blocking;
const World = zhu.ecs.World;
const Entity = zhu.ecs.Entity;

pub const Move = struct {
    from: zhu.Vector2,
    to: zhu.Vector2,
};

// 当前地图每个瓦片上的语义标记，可组合使用。
pub const Mark = enum {
    north, // 北面阻挡
    south, // 南面阻挡
    west, // 西面阻挡
    east, // 东面阻挡
    hazard, // 危险区域
    water, // 水域
    interact, // 可交互
    arable, // 可耕作
    occupied, // 被占用
};

pub const Marks = std.EnumSet(Mark);
const solid = Marks.initMany(&.{ .north, .south, .west, .east });

var map: *const tiled.Map = undefined;
pub var tiles: []Marks = &.{};
pub var areas: std.ArrayList(zhu.Rect) = .empty;

pub fn enter(data: *const tiled.Map) void {
    exit();
    map = data;
    tiles = zhu.assets.oomAlloc(Marks, map.width * map.height);
    @memset(tiles, Marks.initEmpty());
}

pub fn exit() void {
    if (tiles.len > 0) zhu.assets.free(tiles);
    tiles = &.{};
    areas.clearRetainingCapacity();
}

pub fn deinit() void {
    exit();
    areas.clearAndFree(zhu.assets.allocator);
}

pub fn parseSolidLayer(layer: *const tiled.Layer) void {
    for (layer.data, 0..) |gid, index| {
        if (gid != 0) tiles[index].setUnion(solid);
    }
}

/// 根据 tile_flag 字符串设置瓦片标记
pub fn setTileFlag(index: usize, flag: []const u8) void {
    if (index >= tiles.len) return;

    var iter = std.mem.tokenizeScalar(u8, flag, ',');
    while (iter.next()) |raw| {
        const token = std.mem.trim(u8, raw, " \t\r\n");
        if (std.mem.eql(u8, token, "SOLID")) {
            tiles[index].setUnion(solid);
        } else if (std.mem.eql(u8, token, "BLOCK_N")) {
            tiles[index].insert(.north);
        } else if (std.mem.eql(u8, token, "BLOCK_S")) {
            tiles[index].insert(.south);
        } else if (std.mem.eql(u8, token, "BLOCK_W")) {
            tiles[index].insert(.west);
        } else if (std.mem.eql(u8, token, "BLOCK_E")) {
            tiles[index].insert(.east);
        } else if (std.mem.eql(u8, token, "HAZARD")) {
            tiles[index].insert(.hazard);
        } else if (std.mem.eql(u8, token, "WATER")) {
            tiles[index].insert(.water);
        } else if (std.mem.eql(u8, token, "INTERACT")) {
            tiles[index].insert(.interact);
        } else if (std.mem.eql(u8, token, "ARABLE")) {
            tiles[index].insert(.arable);
        } else if (std.mem.eql(u8, token, "OCCUPIED")) {
            tiles[index].insert(.occupied);
        }
    }
}

pub fn clearTileMark(index: usize, mark: Mark) void {
    if (index >= tiles.len) return;
    tiles[index].remove(mark);
}

pub fn marksAt(position: zhu.Vector2) Marks {
    const index = map.worldToTileIndex(position);
    return tiles[index orelse return .initEmpty()];
}

pub fn isSolid(marks: Marks) bool {
    return marks.supersetOf(solid);
}

pub fn hasAnyBlock(marks: Marks) bool {
    return marks.contains(.north) or marks.contains(.south) or
        marks.contains(.west) or marks.contains(.east);
}

pub fn addSolidRect(rect: zhu.Rect) void {
    if (rect.size.x <= 0 or rect.size.y <= 0) return;
    areas.append(zhu.assets.allocator, rect) catch @panic("spatial oom");
}

pub fn addSolidObject(object: tiled.Object) void {
    const tile = map.getTileByGid(object.gid) orelse return;
    const group = tile.objectGroup orelse return;
    const topLeft = object.topLeft();

    for (group.objects) |local| {
        const position = topLeft.add(local.position);
        addSolidRect(zhu.Rect.init(position, local.size));
    }
}

/// 检查碰撞体在指定位置移动 delta 后是否被阻挡
/// delta 表示进入方向：向南移动(d.y>0)遇到 BLOCK_N 表示从北面进入被挡
pub fn isBlocked(
    position: zhu.Vector2,
    collider: Shape,
    delta: zhu.Vector2,
) bool {
    // 将碰撞体偏移到绝对位置
    const shape = collider.move(position);
    const bounds = shape.toRect();
    const mapBounds = zhu.Rect.init(.zero, map.size());
    if (!mapBounds.contains(bounds)) return true;

    var iter = map.tilesInRect(bounds);
    while (iter.next()) |index| {
        const marks = tiles[index];
        if (isSolid(marks)) {
            // 精确检测：圆形用圆-矩形相交，矩形用矩形相交
            const tileRect = map.tileRect(index);
            if (shape.intersect(.{ .rect = tileRect })) return true;
        }
        // 方向阻挡用包围矩形检测（单面墙，精度足够）
        if (delta.y > 0 and marks.contains(.north)) return true;
        if (delta.y < 0 and marks.contains(.south)) return true;
        if (delta.x > 0 and marks.contains(.west)) return true;
        if (delta.x < 0 and marks.contains(.east)) return true;
    }

    // 精确碰撞检测：用 Shape.intersect 与区域矩形相交
    for (areas.items) |area| {
        if (shape.intersect(.{ .rect = area })) return true;
    }
    return false;
}

/// 检查实体能否从当前位置移动到目标位置。
pub fn canMove(world: *World, entity: Entity, move: Move) bool {
    const body = world.get(entity, Shape).?;
    const delta = move.to.sub(move.from);
    if (isBlocked(move.to, body, delta)) return false;

    const moved = body.move(move.to);
    var query = world.query(.{ Position, Shape, Blocking });
    while (query.next()) |other| {
        if (other == entity) continue;

        const otherPosition = query.get(other, Position);
        const otherBody = query.get(other, Shape);
        const otherShape = otherBody.move(otherPosition);
        if (moved.intersect(otherShape)) return false;
    }

    return true;
}

test "isBlocked 检测碰撞框是否与 solid 格子重叠" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    const collider: Shape = .{
        .rect = .init(.xy(-5, -6), .xy(10, 6)),
    };
    // 空地图不应碰撞
    try std.testing.expect(!isBlocked(.xy(24, 40), collider, .xy(1, 1)));

    // 标记 tile (1,2) 为 solid
    tiles[map.worldToTileIndex(.xy(24, 40)).?].setUnion(solid);
    try std.testing.expect(isBlocked(.xy(24, 40), collider, .xy(1, 1)));
    try std.testing.expect(!isBlocked(.xy(80, 80), collider, .xy(1, 1)));
}

test "isBlocked 方向阻挡只在对应方向生效" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    const collider: Shape = .{
        .rect = .init(.zero, .xy(10, 6)),
    };
    const index = map.worldToTileIndex(.xy(40, 40)).?;
    tiles[index].insert(.north); // 北面边缘阻挡

    // 从北面进入（向南移动 delta.y>0）被阻挡
    try std.testing.expect(isBlocked(.xy(36, 27), collider, .xy(0, 1)));
    // 从南面进入（向北移动 delta.y<0）不被阻挡
    try std.testing.expect(!isBlocked(.xy(36, 27), collider, .xy(0, -1)));
    // 水平移动不被阻挡
    try std.testing.expect(!isBlocked(.xy(36, 27), collider, .xy(1, 0)));
}

test "isBlocked 不会把贴边当成碰撞" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    tiles[map.worldToTileIndex(.xy(40, 40)).?].setUnion(solid);
    const collider: Shape = .{
        .rect = .init(.zero, .xy(10, 6)),
    };
    const d = zhu.Vector2.xy(1, 1);

    try std.testing.expect(!isBlocked(.xy(22, 36), collider, d));
    try std.testing.expect(!isBlocked(.xy(36, 26), collider, d));
    try std.testing.expect(isBlocked(.xy(23, 36), collider, d));
}

test "isBlocked 允许碰撞体贴住地图最大边界" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    const collider: Shape = .{
        .rect = .init(.zero, .xy(10, 10)),
    };
    const size = map.size();
    const position = size.sub(.xy(10, 10));

    try std.testing.expect(!isBlocked(position, collider, .zero));
}

test "isBlocked 阻挡碰撞体越过地图边界" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    const collider: Shape = .{
        .rect = .init(.zero, .xy(10, 10)),
    };
    const size = map.size();

    try std.testing.expect(isBlocked(.xy(-0.1, 0), collider, .zero));
    try std.testing.expect(isBlocked(
        .xy(size.x - 9.9, 0),
        collider,
        .zero,
    ));
    try std.testing.expect(isBlocked(.xy(0, -0.1), collider, .zero));
    try std.testing.expect(isBlocked(
        .xy(0, size.y - 9.9),
        collider,
        .zero,
    ));
}

test "对象 collider 使用精确矩形保留桌子间通道" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    addSolidRect(.init(.xy(83.083336, 106.208336), .xy(26.5, 28.25)));
    addSolidRect(.init(.xy(83.04163, 154.22884), .xy(26.5, 28.25)));

    const collider: Shape = .{
        .rect = .init(.xy(-5, -6), .xy(10, 6)),
    };
    const d = zhu.Vector2.xy(1, 1);

    try std.testing.expect(!isBlocked(.xy(96, 144), collider, d));
    try std.testing.expect(isBlocked(.xy(96, 120), collider, d));
}

test "setTileFlag 支持地图语义标记" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    const position = zhu.Vector2.xy(24, 40);
    const index = map.worldToTileIndex(position).?;

    setTileFlag(index, "ARABLE,OCCUPIED,WATER,HAZARD,INTERACT");

    const marks = marksAt(position);
    try std.testing.expect(marks.contains(.arable));
    try std.testing.expect(marks.contains(.occupied));
    try std.testing.expect(marks.contains(.water));
    try std.testing.expect(marks.contains(.hazard));
    try std.testing.expect(marks.contains(.interact));
}

test "setTileFlag 支持 SOLID 与其它标记组合" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    const position = zhu.Vector2.xy(24, 40);
    const index = map.worldToTileIndex(position).?;

    setTileFlag(index, "SOLID,ARABLE");

    const marks = marksAt(position);
    try std.testing.expect(isSolid(marks));
    try std.testing.expect(marks.contains(.arable));
}

test "isBlocked 圆形碰撞体检测 solid 瓦片" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    const collider: Shape = .{
        .circle = .init(.xy(0, -5), 5),
    };

    // 空地图不碰撞
    try std.testing.expect(
        !isBlocked(.xy(24, 40), collider, .xy(1, 1)),
    );

    // solid 格子碰撞
    tiles[map.worldToTileIndex(.xy(24, 40)).?].setUnion(solid);
    try std.testing.expect(
        isBlocked(.xy(24, 40), collider, .xy(1, 1)),
    );
}

test "isBlocked 圆形碰撞体与区域矩形精确碰撞" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    addSolidRect(.init(.xy(83, 106), .xy(26, 28)));

    const collider: Shape = .{
        .circle = .init(.xy(0, -5), 5),
    };
    const d = zhu.Vector2.xy(1, 1);

    // 圆心远离矩形，不碰撞
    try std.testing.expect(!isBlocked(.xy(60, 100), collider, d));
    // 圆心靠近矩形左边缘，碰撞（圆心距矩形 2px，半径 5px）
    try std.testing.expect(isBlocked(.xy(78, 120), collider, d));
}
