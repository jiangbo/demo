const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");

const tiled = zhu.extend.tiled;
const Position = component.Position;
const Shape = component.motion.Shape;
const Blocking = component.motion.Blocking;
const World = zhu.ecs.World;
const Entity = zhu.ecs.Entity;
const SolidRange = component.map.SolidRange;

pub const Hit = struct {};

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
    std.debug.assert(map.tileSize.x == map.tileSize.y);
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
        } else {
            std.debug.panic("unknown tile_flag token: {s}", .{token});
        }
    }
}

pub fn clearTileMark(index: usize, mark: Mark) void {
    if (index >= tiles.len) return;
    tiles[index].remove(mark);
}

pub fn clearTileBlock(index: usize) void {
    if (index >= tiles.len) return;
    tiles[index].remove(.north);
    tiles[index].remove(.south);
    tiles[index].remove(.west);
    tiles[index].remove(.east);
}

pub fn marksAt(position: zhu.Vector2) Marks {
    const index = map.worldToTileIndex(position);
    return tiles[index orelse return .initEmpty()];
}

fn isSolid(marks: Marks) bool {
    return marks.supersetOf(solid);
}

pub fn hasAnyBlock(marks: Marks) bool {
    return marks.contains(.north) or marks.contains(.south) or
        marks.contains(.west) or marks.contains(.east);
}

pub fn canHoeTile(position: zhu.Vector2) bool {
    const marks = marksAt(position);
    if (!marks.contains(.arable)) return false;
    if (marks.contains(.water)) return false;
    if (marks.contains(.occupied)) return false;
    if (hasAnyBlock(marks)) return false;
    return true;
}

pub fn addSolidRect(rect: zhu.Rect) void {
    if (rect.size.x <= 0 or rect.size.y <= 0) return;
    areas.append(zhu.assets.allocator, rect) catch @panic("spatial oom");
}

pub fn addSolidObject(object: tiled.Object) SolidRange {
    const start = areas.items.len;
    const tile = map.getTileByGid(object.gid) orelse
        return .{ .start = start, .count = 0 };
    const group = tile.objectGroup orelse
        return .{ .start = start, .count = 0 };
    const topLeft = object.topLeft();

    for (group.objects) |local| {
        const position = topLeft.add(local.position);
        addSolidRect(zhu.Rect.init(position, local.size));
    }
    return .{ .start = start, .count = areas.items.len - start };
}

// SolidRange 只记录对象加入 areas 时的起点和数量。
pub fn solidAreas(range: SolidRange) []zhu.Rect {
    return areas.items[range.start..][0..range.count];
}

pub fn clearSolidRange(range: SolidRange) void {
    for (solidAreas(range)) |*area| area.* = .init(.zero, .zero);
}

/// 检查碰撞体放在指定位置后是否被阻挡
pub fn isBlocked(position: zhu.Vector2, collider: Shape) bool {
    // 将碰撞体偏移到绝对位置
    const shape = collider.move(position);
    const bounds = shape.toRect();
    const mapBounds = zhu.Rect.init(.zero, map.size());
    if (!mapBounds.contains(bounds)) return true;

    var iter = map.tilesInRect(bounds);
    while (iter.next()) |index| {
        const marks = tiles[index];
        const tileRect = map.tileRect(index);
        if (isSolid(marks)) {
            // 精确检测：圆形用圆-矩形相交，矩形用矩形相交
            if (shape.intersect(tileRect)) return true;
        }

        // 方向标记表示半格阻挡，目标碰撞体进入半格区域就被挡住。
        const size = tileRect.size.x;
        const half = size * 0.5;
        const pos = tileRect.min;
        if (marks.contains(.north)) {
            const rect = zhu.Rect.init(pos, .xy(size, half));
            if (shape.intersect(rect)) return true;
        }
        if (marks.contains(.south)) {
            const rect = zhu.Rect.init(pos.addY(half), .xy(size, half));
            if (shape.intersect(rect)) return true;
        }
        if (marks.contains(.west)) {
            const rect = zhu.Rect.init(pos, .xy(half, size));
            if (shape.intersect(rect)) return true;
        }
        if (marks.contains(.east)) {
            const rect = zhu.Rect.init(pos.addX(half), .xy(half, size));
            if (shape.intersect(rect)) return true;
        }
    }

    // 精确碰撞检测：用 Shape.intersect 与区域矩形相交
    for (areas.items) |area| {
        if (shape.intersect(area)) return true;
    }
    return false;
}

/// 检查实体能否从当前位置移动到目标位置。
pub fn canMove(world: *World, entity: Entity, to: zhu.Vector2) bool {
    const body = world.get(entity, Shape).?;
    if (isBlocked(to, body)) return false;

    const moved = body.move(to);
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

/// 用临时 Hit 标记所有和查询矩形相交的实体。
pub fn markHits(world: *World, rect: zhu.Rect) void {
    world.clear(Hit);

    var query = world.query(.{ Position, Shape });
    while (query.next()) |entity| {
        const position = query.get(entity, Position);
        const body = query.get(entity, Shape);
        if (body.move(position).intersect(rect)) {
            world.add(entity, Hit{});
        }
    }
}

test "markHits 会标记相交的 Shape" {
    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const hit = world.createEntity();
    world.add(hit, Position.xy(4, 0));
    world.add(hit, Shape{ .rect = .init(.zero, .xy(8, 8)) });

    const miss = world.createEntity();
    world.add(miss, Position.xy(32, 0));
    world.add(miss, Shape{ .rect = .init(.zero, .xy(8, 8)) });

    markHits(&world, .init(.zero, .xy(16, 16)));

    try std.testing.expect(world.has(hit, Hit));
    try std.testing.expect(!world.has(miss, Hit));
}

test "markHits 会清理上一次命中结果" {
    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Position.xy(4, 0));
    world.add(entity, Shape{ .rect = .init(.zero, .xy(8, 8)) });

    markHits(&world, .init(.zero, .xy(16, 16)));
    try std.testing.expect(world.has(entity, Hit));

    markHits(&world, .init(.xy(32, 0), .xy(8, 8)));
    try std.testing.expect(!world.has(entity, Hit));
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
    try std.testing.expect(!isBlocked(.xy(24, 40), collider));

    // 标记 tile (1,2) 为 solid
    tiles[map.worldToTileIndex(.xy(24, 40)).?].setUnion(solid);
    try std.testing.expect(isBlocked(.xy(24, 40), collider));
    try std.testing.expect(!isBlocked(.xy(80, 80), collider));
}

test "isBlocked 方向标记会阻挡对应半格" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    const collider: Shape = .{
        .rect = .init(.zero, .xy(10, 6)),
    };
    const index = map.worldToTileIndex(.xy(40, 40)).?;
    tiles[index].insert(.north); // 上半格阻挡

    try std.testing.expect(!isBlocked(.xy(36, 26), collider));
    try std.testing.expect(isBlocked(.xy(36, 27), collider));
    try std.testing.expect(!isBlocked(.xy(36, 41), collider));
}

test "isBlocked 支持南侧半格阻挡" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    const collider: Shape = .{
        .rect = .init(.zero, .xy(8, 8)),
    };
    const index = map.worldToTileIndex(.xy(40, 24)).?;
    tiles[index].insert(.south);

    try std.testing.expect(!isBlocked(.xy(36, 15), collider));
    try std.testing.expect(isBlocked(.xy(36, 17), collider));
}

test "isBlocked 支持东侧半格阻挡" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    const collider: Shape = .{
        .rect = .init(.zero, .xy(8, 8)),
    };
    const index = map.worldToTileIndex(.xy(24, 40)).?;
    tiles[index].insert(.east);

    try std.testing.expect(!isBlocked(.xy(15, 36), collider));
    try std.testing.expect(isBlocked(.xy(17, 36), collider));
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

    try std.testing.expect(!isBlocked(.xy(22, 36), collider));
    try std.testing.expect(!isBlocked(.xy(36, 26), collider));
    try std.testing.expect(isBlocked(.xy(23, 36), collider));
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

    try std.testing.expect(!isBlocked(position, collider));
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

    try std.testing.expect(isBlocked(.xy(-0.1, 0), collider));
    try std.testing.expect(isBlocked(
        .xy(size.x - 9.9, 0),
        collider,
    ));
    try std.testing.expect(isBlocked(.xy(0, -0.1), collider));
    try std.testing.expect(isBlocked(
        .xy(0, size.y - 9.9),
        collider,
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

    try std.testing.expect(!isBlocked(.xy(96, 144), collider));
    try std.testing.expect(isBlocked(.xy(96, 120), collider));
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
    try std.testing.expect(hasAnyBlock(marks));
    try std.testing.expect(marks.contains(.arable));
}

test "canHoeTile 要求可耕作且没有地图阻挡语义" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    const position = zhu.Vector2.xy(24, 40);
    const index = map.worldToTileIndex(position).?;

    try std.testing.expect(!canHoeTile(position));

    tiles[index].insert(.arable);
    try std.testing.expect(canHoeTile(position));

    tiles[index].insert(.water);
    try std.testing.expect(!canHoeTile(position));
    tiles[index].remove(.water);

    tiles[index].insert(.occupied);
    try std.testing.expect(!canHoeTile(position));
    tiles[index].remove(.occupied);

    tiles[index].insert(.north);
    try std.testing.expect(!canHoeTile(position));
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
        !isBlocked(.xy(24, 40), collider),
    );

    // solid 格子碰撞
    tiles[map.worldToTileIndex(.xy(24, 40)).?].setUnion(solid);
    try std.testing.expect(
        isBlocked(.xy(24, 40), collider),
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

    // 圆心远离矩形，不碰撞
    try std.testing.expect(!isBlocked(.xy(60, 100), collider));
    // 圆心靠近矩形左边缘，碰撞（圆心距矩形 2px，半径 5px）
    try std.testing.expect(isBlocked(.xy(78, 120), collider));
}
