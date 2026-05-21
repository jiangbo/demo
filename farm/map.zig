const std = @import("std");
const zhu = @import("zhu");

const template = @import("template.zig");
const spawn = @import("spawn.zig");
const component = @import("component.zig");
const Position = component.Position;

const tiled = zhu.extend.tiled;

pub const maps = [_]tiled.Map{
    @import("zon/school.zon"),
    @import("zon/town.zon"),
};

pub var data: *const tiled.Map = &maps[0];
var vertexes: std.ArrayList(zhu.batch.Vertex) = .empty;
var tiledCount: usize = 0;
pub var cells: []Cell = &.{};
var dryImage: zhu.graphics.Image = undefined;
var wetImage: zhu.graphics.Image = undefined;

pub const Land = enum { dry, wet };

pub const Cell = struct {
    land: ?Land = null,
    crop: ?zhu.ecs.Entity = null,
};

pub fn init() void {
    std.log.info("map init", .{});
    tiled.init(@import("zon/tile.zon"));

    const count = data.width * data.height;
    cells = zhu.assets.oomAlloc(Cell, count);
    @memset(cells, .{});

    dryImage = spawn.resolveImage(template.farm.farmland.dry);
    wetImage = spawn.resolveImage(template.farm.farmland.wet);

    for (data.layers) |*layer| {
        switch (layer.type) {
            .tile => parseTileLayer(layer),
            .image => parseImageLayer(layer),
            .object => {},
        }
    }

    tiledCount = vertexes.items.len;

    std.log.info("map loaded: {}x{}, tiles: {}", //
        .{ data.width, data.height, vertexes.items.len });
}

pub fn deinit() void {
    zhu.assets.free(cells);
    vertexes.clearAndFree(zhu.assets.allocator);
}

pub fn draw() void {
    zhu.batch.vertexBuffer.appendSliceAssumeCapacity(vertexes.items);
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

/// 将 tile 层的每个瓦片转为预构建顶点
/// 流程：gid → 找到所属 tileSet → 算出 tileSet 内的局部 ID
///       → 用 columns 换算行列得到裁剪区域 → sub 裁出子图 → 写入顶点
fn parseTileLayer(layer: *const tiled.Layer) void {
    for (layer.data, 0..) |globalId, index| {
        if (globalId == 0) continue; // 0 表示空瓦片，跳过

        // gid → tileSet 引用 → tileSet 定义 → 局部 ID
        const tileSetRef = data.getTileSetRefByGid(globalId);
        const tileSet = tiled.getTileSetByRef(tileSetRef);
        const localId = globalId - tileSetRef.firstGid;

        // 用 localId 和 columns 算出在 tileSet 图中的裁剪矩形
        const area = data.tileArea(localId, tileSet.columns);
        const image = zhu.assets.getImage(tileSet.image).?.sub(area);
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
    vertexes.shrinkRetainingCapacity(tiledCount);

    for (cells, 0..) |cell, index| {
        const land = cell.land orelse continue;
        const position = data.tileIndexToWorld(index);
        appendVertex(position, dryImage);
        if (land == .wet) appendVertex(position, wetImage);
    }
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
    draw();

    try std.testing.expectEqual(2, zhu.batch.vertexBuffer.items.len);
}

fn putMockLandImages() void {
    const image = zhu.graphics.Image{
        .texture = .{ .id = 1 },
        .size = .xy(256, 256),
    };

    dryImage = image.sub(template.farm.farmland.dry.rect);
    wetImage = image.sub(template.farm.farmland.wet.rect);
}
