const std = @import("std");
const zhu = @import("zhu");

const prefab = @import("prefab.zig");
const component = @import("component.zig");
const factory = @import("factory.zig");
const Position = component.Position;
const Collider = component.Collider;

const tiled = zhu.extend.tiled;

pub const maps = [_]tiled.Map{
    @import("zon/school.zon"),
    @import("zon/town.zon"),
};

pub var data: *const tiled.Map = &maps[0];
var vertexes: std.ArrayList(zhu.batch.Vertex) = .empty;
var frontLayerStart: usize = 0;
var staticLayerEnd: usize = 0;
pub var cells: []Cell = &.{};
pub var solids: []bool = &.{};
var dryImage: zhu.graphics.Image = undefined;
var wetImage: zhu.graphics.Image = undefined;
var mapTexture: zhu.graphics.Texture = undefined;

pub const Land = enum { dry, wet };

pub const Cell = struct {
    land: ?Land = null,
    crop: ?zhu.ecs.Entity = null,
};

pub fn init() void {
    std.log.info("map init", .{});
    tiled.init(@import("zon/tile.zon"));
    vertexes.clearRetainingCapacity();
    frontLayerStart = 0;
    staticLayerEnd = 0;
    mapTexture = zhu.getImage("circle.png").?.texture;

    const count = data.width * data.height;
    cells = zhu.assets.oomAlloc(Cell, count);
    solids = zhu.assets.oomAlloc(bool, count);
    @memset(cells, .{});
    @memset(solids, false);

    dryImage = prefab.resolveImage(prefab.farm.farmland.dry);
    wetImage = prefab.resolveImage(prefab.farm.farmland.wet);

    var foundFrontLayer = false;
    for (data.layers) |*layer| {
        std.log.info("parsing layer: {s}", .{layer.name});
        switch (layer.type) {
            .tile => {
                if (std.mem.eql(u8, layer.name, "solid"))
                    parseSolidLayer(layer)
                else
                    parseTileLayer(layer);
            },
            .image => parseImageLayer(layer),
            .object => {
                if (!foundFrontLayer and std.mem.eql(u8, layer.name, "main")) {
                    frontLayerStart = vertexes.items.len;
                    foundFrontLayer = true;
                }
            },
        }
    }

    staticLayerEnd = vertexes.items.len;
    if (!foundFrontLayer) frontLayerStart = staticLayerEnd;

    std.log.info("map loaded: {}x{}, tiles: {}", //
        .{ data.width, data.height, vertexes.items.len });
}

pub fn deinit() void {
    zhu.assets.free(cells);
    zhu.assets.free(solids);
    vertexes.clearAndFree(zhu.assets.allocator);
}

pub fn drawBack() void {
    if (vertexes.items.len == 0) return;

    _ = zhu.batch.addDrawCommand(mapTexture);
    const back = vertexes.items[0..frontLayerStart];
    zhu.batch.vertexBuffer.appendSliceAssumeCapacity(back);
    const land = vertexes.items[staticLayerEnd..];
    zhu.batch.vertexBuffer.appendSliceAssumeCapacity(land);
}

pub fn drawFront() void {
    if (frontLayerStart == staticLayerEnd) return;
    const front = vertexes.items[frontLayerStart..staticLayerEnd];
    zhu.batch.vertexBuffer.appendSliceAssumeCapacity(front);
}

pub fn loadObjects(world: *zhu.ecs.World) void {
    for (data.layers) |layer| {
        if (layer.type != .object) continue;

        if (std.mem.eql(u8, layer.name, "collider")) {
            for (layer.objects) |object| {
                markSolidRect(.init(object.position, object.size));
            }
            continue;
        }

        for (layer.objects) |object| {
            loadObject(world, object);
        }
    }
}

fn loadObject(world: *zhu.ecs.World, object: tiled.Object) void {
    if (object.gid == 0) return;

    const image = data.imageByGid(object.gid);
    _ = factory.spawnMapImageObject(world, object, image);
    markTileColliders(object, image);
}

pub fn hoe(position: zhu.Vector2) void {
    const cell = getCell(position) orelse return;
    if (cell.land != null or cell.crop != null) return;

    cell.land = .dry;
    rebuildLandVertexes();
}

pub fn water(position: zhu.Vector2) void {
    const cell = getCell(position) orelse return;
    if (cell.land == null) return;
    cell.land = .wet;
    rebuildLandVertexes();
}

pub fn getCell(position: zhu.Vector2) ?*Cell {
    std.debug.assert(cells.len != 0);
    const tile = data.worldToTilePosition(position);
    if (tile.x < 0 or tile.y < 0) return null;

    const width: i32 = @intCast(data.width);
    const height: i32 = @intCast(data.height);
    if (tile.x >= width or tile.y >= height) return null;

    return &cells[@as(usize, @intCast(tile.y * width + tile.x))];
}

/// 检查碰撞框在指定位置是否与 solid 格子重叠
pub fn isSolid(position: zhu.Vector2, collider: Collider) bool {
    // 计算碰撞框在世界中的矩形
    const pos = position.add(collider.offset);
    const rect = zhu.Rect.init(pos, collider.size);

    // 用半开矩形 [min, max) 计算覆盖到的 tile 范围。
    // 右下边界回退一点，避免刚好贴边时多查相邻 tile。
    const tileMin = data.worldToTilePosition(rect.min);
    const max = rect.max().sub(.square(zhu.math.epsilon));
    const tileMax = data.worldToTilePosition(max);
    var y = tileMin.y;
    while (y <= tileMax.y) : (y += 1) {
        var x = tileMin.x;
        while (x <= tileMax.x) : (x += 1) {
            const index = data.tilePositionToIndex(.xy(x, y));
            if (solids[index orelse return true]) return true;
        }
    }
    return false;
}

fn parseSolidLayer(layer: *const tiled.Layer) void {
    for (layer.data, 0..) |gid, index| {
        if (gid != 0) solids[index] = true;
    }
}

pub fn markSolidRect(rect: zhu.Rect) void {
    if (rect.size.x <= 0 or rect.size.y <= 0) return;

    const tileMin = data.worldToTilePosition(rect.min);
    const max = rect.max().sub(.square(zhu.math.epsilon));
    const tileMax = data.worldToTilePosition(max);

    var y = tileMin.y;
    while (y <= tileMax.y) : (y += 1) {
        var x = tileMin.x;
        while (x <= tileMax.x) : (x += 1) {
            const index = data.tilePositionToIndex(.xy(x, y));
            solids[index orelse continue] = true;
        }
    }
}

fn markTileColliders(object: tiled.Object, image: zhu.graphics.Image) void {
    const tile = data.tileByGid(object.gid) orelse return;
    const group = tile.objectGroup orelse return;

    const size = if (object.size.x > 0 and object.size.y > 0)
        object.size
    else
        image.size;
    const scale = size.div(image.size);
    const topLeft = object.position.addY(-size.y);

    for (group.objects) |local| {
        const rect = zhu.Rect.init(
            topLeft.add(local.position.mul(scale)),
            local.size.mul(scale),
        );
        markSolidRect(rect);
    }
}

/// 将 tile 层的每个瓦片转为预构建顶点
/// 流程：gid → 找到所属 tileSet → 算出 tileSet 内的局部 ID
///       → 用 columns 换算行列得到裁剪区域 → sub 裁出子图 → 写入顶点
fn parseTileLayer(layer: *const tiled.Layer) void {
    for (layer.data, 0..) |globalId, index| {
        if (globalId == 0) continue; // 0 表示空瓦片，跳过

        const image = data.imageByGid(globalId);
        appendVertex(data.tileIndexToWorld(index), image);
    }
}

/// 将整张图作为一层背景/前景直接写入顶点
/// image 层没有瓦片网格，就是一张大图放在 offset 位置
fn parseImageLayer(layer: *const tiled.Layer) void {
    const image = zhu.assets.getImage(layer.image).?
        .sub(.init(.zero, .xy(layer.width, layer.height)));
    appendVertex(layer.offset, image);
}

fn appendVertex(position: zhu.Vector2, image: zhu.graphics.Image) void {
    vertexes.append(zhu.assets.allocator, .{
        .position = position,
        .size = image.size,
        .texturePosition = image.toTexturePosition(),
    }) catch @panic("map oom");
}

fn rebuildLandVertexes() void {
    vertexes.shrinkRetainingCapacity(staticLayerEnd);

    for (cells, 0..) |cell, index| {
        const land = cell.land orelse continue;
        const position = data.tileIndexToWorld(index);
        appendVertex(position, dryImage);
        if (land == .wet) appendVertex(position, wetImage);
    }
}

test "isSolid 检测碰撞框是否与 solid 格子重叠" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    solids = zhu.assets.oomAlloc(bool, data.width * data.height);
    defer zhu.assets.free(solids);
    @memset(solids, false);

    // 空地图不应碰撞
    const collider: component.Collider = .{
        .size = .xy(10, 6),
        .offset = .xy(-5, -6),
    };
    try std.testing.expect(!isSolid(.xy(24, 40), collider));

    // 标记 tile (1,2) 为 solid（世界坐标 16~32, 32~48）
    solids[data.worldToTileIndex(.xy(24, 40)).?] = true;

    // 碰撞框与 solid 格子重叠时应返回 true
    try std.testing.expect(isSolid(.xy(24, 40), collider));

    // 碰撞框不与 solid 格子重叠时应返回 false
    try std.testing.expect(!isSolid(.xy(80, 80), collider));
}

test "isSolid 不会把贴边当成碰撞" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    solids = zhu.assets.oomAlloc(bool, data.width * data.height);
    defer zhu.assets.free(solids);
    @memset(solids, false);

    // solid tile (2,2) 的世界范围是 32~48, 32~48
    solids[data.worldToTileIndex(.xy(40, 40)).?] = true;

    const collider: component.Collider = .{
        .size = .xy(10, 6),
    };

    // 右边界刚好贴到 solid 的左边界 x=32，不应算重叠
    try std.testing.expect(!isSolid(.xy(22, 36), collider));

    // 下边界刚好贴到 solid 的上边界 y=32，不应算重叠
    try std.testing.expect(!isSolid(.xy(36, 26), collider));

    // 真正进入 solid 1 像素后才应算碰撞
    try std.testing.expect(isSolid(.xy(23, 36), collider));
}

test "isSolid 会把地图外当成阻挡" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    solids = zhu.assets.oomAlloc(bool, data.width * data.height);
    defer zhu.assets.free(solids);
    @memset(solids, false);

    const collider: component.Collider = .{
        .size = .xy(4, 4),
    };

    try std.testing.expect(isSolid(.xy(-1, 16), collider));
    try std.testing.expect(isSolid(.xy(16, -1), collider));
    try std.testing.expect(isSolid(data.size().sub(.xy(3, 3)), collider));
}

test "gid 图片解析支持单图和集合图块集" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    tiled.init(@import("zon/tile.zon"));

    const old = data;
    defer data = old;
    data = &maps[1];

    const mockImage = zhu.graphics.Image{
        .texture = .{ .id = 1 },
        .size = .xy(10, 10),
    };

    var singleGid: u32 = 0;
    for (data.tileSetRefs) |ref| {
        const tileSet = tiled.tileSetByRef(ref);
        if (tileSet.columns == 0) continue;
        zhu.assets.putImage(tileSet.image, mockImage);
        singleGid = ref.firstGid;
        break;
    }
    try std.testing.expect(singleGid != 0);
    try std.testing.expectEqual(@as(u32, 1), data.imageByGid(singleGid).texture.id);

    var collectionGid: u32 = 0;
    for (data.tileSetRefs) |ref| {
        const tileSet = tiled.tileSetByRef(ref);
        if (tileSet.columns != 0) continue;
        for (tileSet.tiles, 0..) |tile, localId| {
            if (tile.id == 0) continue;
            zhu.assets.putImage(tile.id, mockImage);
            collectionGid = ref.firstGid + @as(u32, @intCast(localId));
            break;
        }
        if (collectionGid != 0) break;
    }
    try std.testing.expect(collectionGid != 0);
    try std.testing.expectEqual(@as(u32, 1), data.imageByGid(collectionGid).texture.id);
}

test "markSolidRect 会标记矩形覆盖到的格子" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();

    solids = zhu.assets.oomAlloc(bool, data.width * data.height);
    defer zhu.assets.free(solids);
    @memset(solids, false);

    markSolidRect(.init(.xy(32, 32), .xy(16, 16)));

    try std.testing.expect(solids[data.worldToTileIndex(.xy(40, 40)).?]);
    try std.testing.expect(!solids[data.worldToTileIndex(.xy(24, 40)).?]);
}

test "锄地会记录目标格" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    cells = zhu.assets.oomAlloc(Cell, data.width * data.height);
    defer zhu.assets.free(cells);
    @memset(cells, .{});
    putMockLandImages();
    defer vertexes.clearAndFree(std.testing.allocator);

    hoe(.xy(32, 48));

    try std.testing.expectEqual(Land.dry, getCell(.xy(32, 48)).?.land);
}

test "浇水只会影响已有耕地" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    cells = zhu.assets.oomAlloc(Cell, data.width * data.height);
    defer zhu.assets.free(cells);
    @memset(cells, .{});
    putMockLandImages();
    defer vertexes.clearAndFree(std.testing.allocator);

    water(.xy(32, 48));
    try std.testing.expectEqual(null, getCell(.xy(32, 48)).?.land);

    hoe(.xy(32, 48));
    water(.xy(32, 48));
    try std.testing.expectEqual(Land.wet, getCell(.xy(32, 48)).?.land);
}

test "目标格有作物时不会锄地" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    cells = zhu.assets.oomAlloc(Cell, data.width * data.height);
    defer zhu.assets.free(cells);
    @memset(cells, .{});
    putMockLandImages();
    defer vertexes.clearAndFree(std.testing.allocator);

    getCell(.xy(32, 48)).?.crop = 1;

    hoe(.xy(32, 48));
    try std.testing.expectEqual(null, getCell(.xy(32, 48)).?.land);
}

test "土地绘制会追加干湿图块" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    cells = zhu.assets.oomAlloc(Cell, data.width * data.height);
    defer zhu.assets.free(cells);
    putMockLandImages();
    defer vertexes.clearAndFree(std.testing.allocator);
    @memset(cells, .{});

    var vertices: [8]zhu.batch.Vertex = undefined;
    var commands: [16]zhu.batch.Command = undefined;
    zhu.batch.vertexBuffer = .initBuffer(&vertices);
    zhu.batch.commandBuffer = .initBuffer(&commands);
    zhu.batch.commandBuffer.appendAssumeCapacity(.{});

    hoe(.xy(32, 48));
    water(.xy(32, 48));
    drawBack();

    try std.testing.expectEqual(2, zhu.batch.vertexBuffer.items.len);
}

test "地图绘制会把前景留到实体之后" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    defer vertexes.clearAndFree(std.testing.allocator);

    vertexes.clearRetainingCapacity();
    frontLayerStart = 0;
    staticLayerEnd = 0;

    const image = zhu.graphics.Image{
        .texture = .{ .id = 1 },
        .size = .xy(1, 1),
    };
    mapTexture = image.texture;

    appendVertex(.xy(1, 0), image); // back
    frontLayerStart = vertexes.items.len;
    appendVertex(.xy(2, 0), image); // front
    staticLayerEnd = vertexes.items.len;
    appendVertex(.xy(3, 0), image); // dynamic land

    var vertices: [8]zhu.batch.Vertex = undefined;
    var commands: [4]zhu.batch.Command = undefined;
    zhu.batch.vertexBuffer = .initBuffer(&vertices);
    zhu.batch.commandBuffer = .initBuffer(&commands);

    drawBack();

    try std.testing.expectEqual(@as(usize, 2), zhu.batch.vertexBuffer.items.len);
    try std.testing.expectEqual(@as(f32, 1), zhu.batch.vertexBuffer.items[0].position.x);
    try std.testing.expectEqual(@as(f32, 3), zhu.batch.vertexBuffer.items[1].position.x);

    drawFront();

    try std.testing.expectEqual(@as(usize, 3), zhu.batch.vertexBuffer.items.len);
    try std.testing.expectEqual(@as(f32, 2), zhu.batch.vertexBuffer.items[2].position.x);
}

fn putMockLandImages() void {
    const image = zhu.graphics.Image{
        .texture = .{ .id = 1 },
        .size = .xy(256, 256),
    };

    frontLayerStart = 0;
    staticLayerEnd = 0;
    mapTexture = image.texture;
    dryImage = image.sub(prefab.farm.farmland.dry.rect);
    wetImage = image.sub(prefab.farm.farmland.wet.rect);
}
