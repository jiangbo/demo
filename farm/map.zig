const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const template = @import("template.zig");

const batch = zhu.batch;
const tiled = zhu.extend.tiled;

pub const maps = [_]tiled.Map{
    @import("zon/school.zon"),
};

pub var data: *const tiled.Map = &maps[0];
var tileVertexes: std.ArrayList(batch.Vertex) = .empty;
var cells: []Cell = &.{};
var dryImage: zhu.graphics.Image = undefined;
var wetImage: zhu.graphics.Image = undefined;

const Land = enum {
    none,
    dry,
    wet,
};

const Cell = struct {
    land: Land = .none,
    crop: ?zhu.ecs.Entity = null,
};

pub fn init() void {
    std.log.info("map init", .{});
    tiled.init(@import("zon/tile.zon"));

    zhu.assets.free(cells);
    const count: usize = @intCast(data.width * data.height);
    cells = zhu.assets.oomAlloc(Cell, count);
    @memset(cells, .{});

    const drySprite = template.farm.farmland.dry;
    const wetSprite = template.farm.farmland.wet;
    dryImage = zhu.getImage(drySprite.path).?.sub(drySprite.rect);
    wetImage = zhu.getImage(wetSprite.path).?.sub(wetSprite.rect);

    for (data.layers) |*layer| {
        switch (layer.type) {
            .tile => parseTileLayer(layer),
            .image => parseImageLayer(layer),
            .object => {},
        }
    }

    std.log.info("map loaded: {}x{}, tiles: {}", //
        .{ data.width, data.height, tileVertexes.items.len });
}

pub fn deinit() void {
    zhu.assets.free(cells);
    cells = &.{};
    tileVertexes.clearAndFree(zhu.assets.allocator);
}

pub fn draw() void {
    batch.vertexBuffer.appendSliceAssumeCapacity(tileVertexes.items);

    for (cells, 0..) |cell, index| {
        const position = data.tileIndexToWorld(index);
        switch (cell.land) {
            .none => {},
            .dry => zhu.batch.drawImage(dryImage, position, .{}),
            .wet => {
                zhu.batch.drawImage(dryImage, position, .{});
                zhu.batch.drawImage(wetImage, position, .{});
            },
        }
    }
}

pub fn rebuild(world: *zhu.ecs.World) void {
    for (cells) |*cell| cell.crop = null;

    var query = world.query(.{ component.Position, component.Crop });
    while (query.next()) |entity| {
        const index = cellIndex(query.get(entity, component.Position)) orelse continue;
        cells[index].crop = entity;
    }
}

pub fn hoe(position: zhu.Vector2) void {
    const index = cellIndex(position) orelse return;
    const cell = &cells[index];
    if (cell.land != .none) return;
    if (cell.crop != null) return;

    cell.land = .dry;
}

pub fn water(position: zhu.Vector2) void {
    const index = cellIndex(position) orelse return;
    const cell = &cells[index];
    if (cell.land == .none) return;

    cell.land = .wet;
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

        tileVertexes.append(zhu.assets.allocator, .{
            .position = data.tileIndexToWorld(index), // 索引 → 世界坐标
            .size = image.size,
            .texturePosition = image.toTexturePosition(),
        }) catch @panic("oom, can't append tile");
    }
}

/// 将整张图作为一层背景/前景直接写入顶点
/// image 层没有瓦片网格，就是一张大图放在 offset 位置
fn parseImageLayer(layer: *const tiled.Layer) void {
    const image = zhu.assets.getImage(layer.image).?;
    tileVertexes.append(zhu.assets.allocator, .{
        .position = layer.offset,
        .size = .xy(layer.width, layer.height),
        .texturePosition = image.toTexturePosition(),
    }) catch @panic("oom, can't append image layer");
}

fn cellIndex(position: zhu.Vector2) ?usize {
    std.debug.assert(cells.len != 0);
    const tile = data.worldToTilePosition(position);
    if (tile.x < 0 or tile.y < 0) return null;

    const width: i32 = @intCast(data.width);
    const height: i32 = @intCast(data.height);
    if (tile.x >= width or tile.y >= height) return null;

    return @intCast(tile.y * width + tile.x);
}

test "锄地会记录目标格" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    cells = zhu.assets.oomAlloc(Cell, @intCast(data.width * data.height));
    defer {
        zhu.assets.free(cells);
        cells = &.{};
    }
    @memset(cells, .{});

    hoe(.xy(32, 48));

    const index = cellIndex(.xy(32, 48)).?;
    try std.testing.expectEqual(Land.dry, cells[index].land);
}

test "浇水只会影响已有耕地" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    cells = zhu.assets.oomAlloc(Cell, @intCast(data.width * data.height));
    defer {
        zhu.assets.free(cells);
        cells = &.{};
    }
    @memset(cells, .{});

    water(.xy(32, 48));
    var index = cellIndex(.xy(32, 48)).?;
    try std.testing.expectEqual(Land.none, cells[index].land);

    hoe(.xy(32, 48));
    water(.xy(32, 48));
    index = cellIndex(.xy(32, 48)).?;
    try std.testing.expectEqual(Land.wet, cells[index].land);
}

test "目标格有作物时不会锄地" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    cells = zhu.assets.oomAlloc(Cell, @intCast(data.width * data.height));
    defer {
        zhu.assets.free(cells);
        cells = &.{};
    }
    @memset(cells, .{});

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const crop = world.createEntity();
    world.add(crop, component.Crop{});
    world.add(crop, component.Position.xy(40, 56));
    rebuild(&world);

    hoe(.xy(32, 48));
    const index = cellIndex(.xy(32, 48)).?;
    try std.testing.expectEqual(Land.none, cells[index].land);
}

test "土地绘制会追加干湿图块" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    cells = zhu.assets.oomAlloc(Cell, @intCast(data.width * data.height));
    defer {
        zhu.assets.free(cells);
        cells = &.{};
    }
    putMockLandImages();
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

    var id = zhu.assets.id(template.farm.farmland.dry.path);
    zhu.assets.putImage(id, image);
    dryImage = zhu.assets.getImage(id).?.sub(template.farm.farmland.dry.rect);
    id = zhu.assets.id(template.farm.farmland.wet.path);
    zhu.assets.putImage(id, image);
    wetImage = zhu.assets.getImage(id).?.sub(template.farm.farmland.wet.rect);
}
