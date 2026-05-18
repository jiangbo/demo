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

fn parseTileLayer(layer: *const tiled.Layer) void {
    for (layer.data, 0..) |gid, index| {
        if (gid == 0) continue;

        const position = data.tileIndexToWorld(index);
        const tileSetRef = data.getTileSetRefByGid(gid);
        const tileSet = tiled.getTileSetByRef(tileSetRef);
        const localId = gid - tileSetRef.firstGid;

        const tileImage = zhu.assets.getImage(tileSet.image).?;
        const area = data.tileArea(localId, tileSet.columns);
        const image = tileImage.sub(area);

        tileVertexes.append(zhu.assets.allocator, .{
            .position = position,
            .size = image.size,
            .texturePosition = image.toTexturePosition(),
        }) catch @panic("oom, can't append tile");
    }
}

fn parseImageLayer(layer: *const tiled.Layer) void {
    if (layer.image == 0) return;

    const image = zhu.assets.getImage(layer.image).?;
    tileVertexes.append(zhu.assets.allocator, .{
        .position = layer.offset,
        .size = .xy(layer.width, layer.height),
        .texturePosition = image.toTexturePosition(),
    }) catch @panic("oom, can't append image layer");
}
