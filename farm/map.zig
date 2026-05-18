const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;
const tiled = zhu.extend.tiled;

pub const maps = [_]tiled.Map{
    @import("zon/school.zon"),
};

pub var data: *const tiled.Map = &maps[0];
var tileVertexes: std.ArrayList(batch.Vertex) = .empty;

pub fn init() void {
    std.log.info("map init", .{});
    tiled.init(@import("zon/tile.zon"));

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
    tileVertexes.clearAndFree(zhu.assets.allocator);
}

pub fn draw() void {
    batch.vertexBuffer.appendSliceAssumeCapacity(tileVertexes.items);
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
