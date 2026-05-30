const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");

const tiled = zhu.extend.tiled;
const Collider = component.motion.Collider;

var map: *const tiled.Map = undefined;
pub var tiles: []bool = &.{};
pub var areas: std.ArrayList(zhu.Rect) = .empty;

pub fn enter(data: *const tiled.Map) void {
    exit();
    map = data;
    tiles = zhu.assets.oomAlloc(bool, map.width * map.height);
    @memset(tiles, false);
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
        if (gid != 0) tiles[index] = true;
    }
}

pub fn markSolidRect(rect: zhu.Rect) void {
    if (rect.size.x <= 0 or rect.size.y <= 0) return;

    const tileMin = map.worldToTilePosition(rect.min);
    const max = rect.max().sub(.square(zhu.math.epsilon));
    const tileMax = map.worldToTilePosition(max);

    var y = tileMin.y;
    while (y <= tileMax.y) : (y += 1) {
        var x = tileMin.x;
        while (x <= tileMax.x) : (x += 1) {
            const index = map.tilePositionToIndex(.xy(x, y));
            tiles[index orelse continue] = true;
        }
    }
}

pub fn markSolidTile(position: zhu.Vector2) void {
    const index = map.worldToTileIndex(position).?;
    const tilePosition = map.tileIndexToWorld(index);
    markSolidRect(.init(tilePosition, map.tileSize));
}

pub fn addSolidRect(rect: zhu.Rect) void {
    if (rect.size.x <= 0 or rect.size.y <= 0) return;
    areas.append(zhu.assets.allocator, rect) catch @panic("physics oom");
}

pub fn addSolidObject(object: tiled.Object) void {
    const tile = map.getTileByGid(object.gid) orelse return;
    const group = tile.objectGroup orelse return;
    const topLeft = object.position.addY(-object.size.y);

    for (group.objects) |local| {
        const position = topLeft.add(local.position);
        addSolidRect(zhu.Rect.init(position, local.size));
    }
}

/// 检查碰撞框在指定位置是否与 solid 格子重叠
pub fn isSolid(position: zhu.Vector2, collider: Collider) bool {
    // 计算碰撞框在世界中的矩形
    const pos = position.add(collider.offset);
    const rect = zhu.Rect.init(pos, collider.size);

    // 用半开矩形 [min, max) 计算覆盖到的 tile 范围。
    // 右下边界回退一点，避免刚好贴边时多查相邻 tile。
    const tileMin = map.worldToTilePosition(rect.min);
    const max = rect.max().sub(.square(zhu.math.epsilon));
    const tileMax = map.worldToTilePosition(max);
    var y = tileMin.y;
    while (y <= tileMax.y) : (y += 1) {
        var x = tileMin.x;
        while (x <= tileMax.x) : (x += 1) {
            const index = map.tilePositionToIndex(.xy(x, y));
            if (tiles[index orelse return true]) return true;
        }
    }

    for (areas.items) |solid| if (rect.intersect(solid)) return true;
    return false;
}

test "isSolid 检测碰撞框是否与 solid 格子重叠" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    // 空地图不应碰撞
    const collider: Collider = .{
        .size = .xy(10, 6),
        .offset = .xy(-5, -6),
    };
    try std.testing.expect(!isSolid(.xy(24, 40), collider));

    // 标记 tile (1,2) 为 solid（世界坐标 16~32, 32~48）
    tiles[map.worldToTileIndex(.xy(24, 40)).?] = true;

    // 碰撞框与 solid 格子重叠时应返回 true
    try std.testing.expect(isSolid(.xy(24, 40), collider));

    // 碰撞框不与 solid 格子重叠时应返回 false
    try std.testing.expect(!isSolid(.xy(80, 80), collider));
}

test "isSolid 不会把贴边当成碰撞" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    // solid tile (2,2) 的世界范围是 32~48, 32~48
    tiles[map.worldToTileIndex(.xy(40, 40)).?] = true;

    const collider: Collider = .{ .size = .xy(10, 6) };

    // 右边界刚好贴到 solid 的左边界 x=32，不应算重叠
    try std.testing.expect(!isSolid(.xy(22, 36), collider));

    // 下边界刚好贴到 solid 的上边界 y=32，不应算重叠
    try std.testing.expect(!isSolid(.xy(36, 26), collider));

    // 真正进入 solid 1 像素后才应算碰撞
    try std.testing.expect(isSolid(.xy(23, 36), collider));
}

test "isSolid 会把地图外当成阻挡" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    const collider: Collider = .{ .size = .xy(4, 4) };

    try std.testing.expect(isSolid(.xy(-1, 16), collider));
    try std.testing.expect(isSolid(.xy(16, -1), collider));
    try std.testing.expect(isSolid(map.size().sub(.xy(3, 3)), collider));
}

test "对象 collider 使用精确矩形保留桌子间通道" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    addSolidRect(.init(.xy(83.083336, 106.208336), .xy(26.5, 28.25)));
    addSolidRect(.init(.xy(83.04163, 154.22884), .xy(26.5, 28.25)));

    const collider: Collider = .{
        .size = .xy(10, 6),
        .offset = .xy(-5, -6),
    };

    try std.testing.expect(!isSolid(.xy(96, 144), collider));
    try std.testing.expect(isSolid(.xy(96, 120), collider));
}

test "markSolidRect 会标记矩形覆盖到的格子" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    markSolidRect(.init(.xy(32, 32), .xy(16, 16)));

    try std.testing.expect(tiles[map.worldToTileIndex(.xy(40, 40)).?]);
    try std.testing.expect(!tiles[map.worldToTileIndex(.xy(24, 40)).?]);
}
