const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;
const tiled = zhu.extend.tiled;

const level: tiled.Map = @import("zon/level1.zon");
const map = level;
const Animation = struct {
    position: zhu.Vector2,
    value: zhu.graphics.Animation,
    extend: tiled.ObjectExtend = .{},
};
var animations: std.ArrayList(Animation) = .empty;

var tileVertexes: std.ArrayList(batch.Vertex) = .empty;

pub fn init() void {
    tiled.backgroundColor = level.backgroundColor;

    for (level.layers) |*layer| {
        switch (layer.type) {
            .tile => parseTileLayer(layer),
            .object => parseObjectLayer(layer),
            else => unreachable,
        }
    }

    std.mem.sortUnstable(Animation, animations.items, {}, struct {
        fn lessThan(_: void, a: Animation, b: Animation) bool {
            return a.position.y < b.position.y;
        }
    }.lessThan);
}

pub fn deinit() void {
    tileVertexes.deinit(zhu.assets.allocator);
    animations.deinit(zhu.assets.allocator);
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
        if (tile != null and tile.?.animation.len > 0) {
            image = zhu.assets.getImage(tileSet.image);
            animations.append(zhu.assets.allocator, .{
                .position = pos,
                .value = .init(image, tile.?.animation),
            }) catch @panic("oom, can't append animation");
            continue;
        }

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
            .texturePosition = image.toTexturePosition(),
        }) catch @panic("oom, can't append tile");

        // if (tile) |t| parseProperties(index, t); // 解析碰撞信息
    }
}

fn parseObjectLayer(layer: *const tiled.Layer) void {
    for (layer.objects) |object| {
        if (object.gid == 0) {
            std.log.info("gid 0, position: {}", .{object.position});
            continue;
        }

        const tileSetRef = map.getTileSetRefByGid(object.gid);
        const tileSet = tiled.getTileSetByRef(tileSetRef);
        const localId = object.gid - tileSetRef.firstGid;

        const tile = tileSet.getTileByLocalId(localId);

        if (tile == null) {
            std.log.info("tile is null, gid: {}", .{object.gid});
            continue;
        }

        const pos = object.position.addY(-object.size.y);
        if (tileSet.columns == 0) {
            const image = zhu.assets.getImage(tile.?.id);
            tileVertexes.append(zhu.assets.allocator, .{
                .position = pos,
                .size = object.size,
                .texturePosition = image.toTexturePosition(),
            }) catch @panic("oom, can't append tile");
        } else {
            const image = zhu.assets.getImage(tileSet.image);
            animations.append(zhu.assets.allocator, .{
                .position = pos,
                .value = .init(image, tile.?.animation),
                .extend = object.extend,
            }) catch @panic("oom, can't append animation");
        }
    }
}

pub fn update(delta: f32) void {
    for (animations.items) |*item| item.value.loopUpdate(delta);
}

pub fn draw() void {
    batch.currentCommand().texture = batch.whiteImage.texture;
    batch.vertexBuffer.appendSliceAssumeCapacity(tileVertexes.items);

    for (animations.items) |item| {
        batch.drawImage(item.value.currentImage(), item.position, .{
            .flipX = item.extend.flipX,
        });
    }
}
