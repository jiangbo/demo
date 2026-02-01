const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;
const tiled = zhu.extend.tiled;

const level: tiled.Map = @import("zon/level1.zon");
const map = level;

var tileVertexes: std.ArrayList(batch.Vertex) = .empty;

pub fn init() void {
    tiled.backgroundColor = level.backgroundColor;

    for (level.layers) |layer| {
        std.log.info("layer name: {s}", .{layer.name});

        switch (layer.type) {
            .tile => parseTileLayer(&layer),
            .object => {},
            else => unreachable,
        }
    }
}

pub fn deinit() void {
    tileVertexes.deinit(zhu.assets.allocator);
}

fn parseTileLayer(layer: *const tiled.Layer) void {
    const ts = tiled.getTileSetById(zhu.id("Tilemap.tsj"));
    const tileImage = zhu.assets.getImage(ts.image);

    for (layer.data, 0..) |gid, index| {
        if (gid == 0) continue;

        const x: f32 = @floatFromInt(index % map.width);
        const y: f32 = @floatFromInt(index / map.width);
        var pos = map.tileSize.mul(.xy(x, y));

        var image: zhu.graphics.Image = undefined;
        const tileSetRef = map.getTileSetRefByGid(gid);
        const tileSet = tiled.getTileSetByRef(tileSetRef);
        const localId = gid - tileSetRef.firstGid;

        const tile = tileSet.getTileByLocalId(localId);
        if (tileSet.columns == 0) { // 单图片瓦片集的列数
            image = zhu.assets.getImage(tile.?.id);
            pos.y = pos.y - image.area.size.y + map.tileSize.y;
        } else {
            const area = map.tileArea(localId, tileSet.columns);
            image = tileImage.sub(area);
        }

        tileVertexes.append(zhu.assets.allocator, .{
            .position = pos,
            .size = image.area.size,
            .texturePosition = image.area.toTexturePosition(),
        }) catch @panic("oom, can't append tile");

        // if (tile) |t| parseProperties(index, t); // 解析碰撞信息
    }
}

pub fn update(delta: f32) void {
    _ = delta;
}

pub fn draw() void {
    batch.currentCommand().texture = batch.whiteImage.texture;
    batch.vertexBuffer.appendSliceAssumeCapacity(tileVertexes.items);
}
