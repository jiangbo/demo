const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");

const tiled = zhu.extend.tiled;
const Collider = component.motion.Collider;

// 方向阻挡位标记
pub const Block = struct {
    pub const N: u8 = 1 << 0; // 北面阻挡
    pub const S: u8 = 1 << 1;
    pub const W: u8 = 1 << 2;
    pub const E: u8 = 1 << 3;
    pub const SOLID: u8 = N | S | W | E;
};

var map: *const tiled.Map = undefined;
pub var tiles: []u8 = &.{};
pub var areas: std.ArrayList(zhu.Rect) = .empty;

pub fn enter(data: *const tiled.Map) void {
    exit();
    map = data;
    tiles = zhu.assets.oomAlloc(u8, map.width * map.height);
    @memset(tiles, 0);
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
        if (gid != 0) tiles[index] = Block.SOLID;
    }
}

/// 根据 tile_flag 字符串设置方向阻挡标记
pub fn setTileFlag(index: usize, flag: []const u8) void {
    if (std.mem.containsAtLeast(u8, flag, 1, "SOLID")) {
        tiles[index] = Block.SOLID;
        return;
    }
    if (std.mem.containsAtLeast(u8, flag, 1, "BLOCK_N")) tiles[index] |= Block.N;
    if (std.mem.containsAtLeast(u8, flag, 1, "BLOCK_S")) tiles[index] |= Block.S;
    if (std.mem.containsAtLeast(u8, flag, 1, "BLOCK_W")) tiles[index] |= Block.W;
    if (std.mem.containsAtLeast(u8, flag, 1, "BLOCK_E")) tiles[index] |= Block.E;
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

/// 检查碰撞框在指定位置移动 delta 后是否被阻挡
/// delta 表示进入方向：向南移动(d.y>0)遇到 BLOCK_N 表示从北面进入被挡
pub fn isBlocked(
    position: zhu.Vector2,
    collider: Collider,
    delta: zhu.Vector2,
) bool {
    const pos = position.add(collider.offset);
    const rect = zhu.Rect.init(pos, collider.size);

    var iter = map.tilesInRect(rect);
    if (iter.outside) return true;

    while (iter.next()) |tile| {
        const flags = tiles[tile.index];
        if (flags == Block.SOLID) return true;
        // 从北面进入（向南移动），遇到 BLOCK_N 被挡
        if (delta.y > 0 and flags & Block.N != 0) return true;
        if (delta.y < 0 and flags & Block.S != 0) return true;
        if (delta.x > 0 and flags & Block.W != 0) return true;
        if (delta.x < 0 and flags & Block.E != 0) return true;
    }

    for (areas.items) |solid| if (rect.intersect(solid)) return true;
    return false;
}

test "isBlocked 检测碰撞框是否与 solid 格子重叠" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    const collider: Collider = .{
        .size = .xy(10, 6),
        .offset = .xy(-5, -6),
    };
    // 空地图不应碰撞
    try std.testing.expect(!isBlocked(.xy(24, 40), collider, .xy(1, 1)));

    // 标记 tile (1,2) 为 solid
    tiles[map.worldToTileIndex(.xy(24, 40)).?] = Block.SOLID;
    try std.testing.expect(isBlocked(.xy(24, 40), collider, .xy(1, 1)));
    try std.testing.expect(!isBlocked(.xy(80, 80), collider, .xy(1, 1)));
}

test "isBlocked 方向阻挡只在对应方向生效" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    const collider: Collider = .{ .size = .xy(10, 6) };
    const index = map.worldToTileIndex(.xy(40, 40)).?;
    tiles[index] = Block.N; // 北面边缘阻挡

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

    tiles[map.worldToTileIndex(.xy(40, 40)).?] = Block.SOLID;
    const collider: Collider = .{ .size = .xy(10, 6) };
    const d = zhu.Vector2.xy(1, 1);

    try std.testing.expect(!isBlocked(.xy(22, 36), collider, d));
    try std.testing.expect(!isBlocked(.xy(36, 26), collider, d));
    try std.testing.expect(isBlocked(.xy(23, 36), collider, d));
}

test "isBlocked 会把地图外当成阻挡" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    const collider: Collider = .{ .size = .xy(4, 4) };
    const d = zhu.Vector2.xy(1, 1);

    try std.testing.expect(isBlocked(.xy(-1, 16), collider, d));
    try std.testing.expect(isBlocked(.xy(16, -1), collider, d));
    try std.testing.expect(isBlocked(map.size().sub(.xy(3, 3)), collider, d));
}

test "对象 collider 使用精确矩形保留桌子间通道" {
    zhu.assets.allocator = std.testing.allocator;
    const testMaps = [_]tiled.Map{@import("../zon/map/school.zon")};
    enter(&testMaps[0]);
    defer deinit();

    addSolidRect(.init(.xy(83.083336, 106.208336), .xy(26.5, 28.25)));
    addSolidRect(.init(.xy(83.04163, 154.22884), .xy(26.5, 28.25)));

    const collider: Collider = .{
        .size = .xy(10, 6),
        .offset = .xy(-5, -6),
    };
    const d = zhu.Vector2.xy(1, 1);

    try std.testing.expect(!isBlocked(.xy(96, 144), collider, d));
    try std.testing.expect(isBlocked(.xy(96, 120), collider, d));
}
