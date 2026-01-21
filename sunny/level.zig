const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const batch = zhu.batch;
const tiled = zhu.extend.tiled;

const level1: tiled.Map = @import("zon/level1.zon");
var tiles: std.ArrayList(tiled.Tile) = .empty;

pub fn init() void {
    for (level1.layers) |layer| {
        if (layer.type == .tile) parseTileLayer(&layer);
    }
}

pub fn deinit() void {
    tiles.deinit(zhu.assets.allocator);
}

fn parseTileLayer(layer: *const tiled.Layer) void {
    const width: u32 = @intFromFloat(layer.width);

    var firstImage = zhu.assets.getImage(level1.tileSets[0].images[0]);
    for (layer.data, 0..) |tileIndex, index| {
        if (tileIndex == 0) continue;

        const tileSet = blk: for (level1.tileSets) |tileSet| {
            if (tileIndex < tileSet.max) break :blk tileSet;
        } else unreachable;

        const x: f32 = @floatFromInt(index % width);
        const y: f32 = @floatFromInt(index / width);
        var pos = level1.tileSize.mul(.xy(x, y));

        var image: zhu.graphics.Image = undefined;
        const id = tileIndex - tileSet.min;
        const columns = tileSet.columns; // 单图片瓦片集的列数
        if (columns == 0) {
            image = zhu.assets.getImage(tileSet.images[id]);
            pos.y = pos.y - image.area.size.y + level1.tileSize.y;
        } else {
            const area = tiled.tileArea(id, level1.tileSize, columns);
            image = firstImage.sub(area);
        }

        tiles.append(zhu.assets.allocator, .{
            .image = image,
            .position = pos,
        }) catch @panic("oom, can't append tile");
    }
}

pub fn draw() void {
    for (level1.layers) |*layer| {
        if (layer.type == .image) drawImageLayer(layer);
    }

    for (tiles.items) |tile| {
        batch.drawImage(tile.image, tile.position, .{});
    }
}

fn drawImageLayer(layer: *const tiled.Layer) void {
    zhu.camera.modeEnum = .window;
    defer zhu.camera.modeEnum = .world;

    if (layer.repeatY) {
        const posY = zhu.camera.position.y * layer.parallaxY;
        var y = -@mod(posY, layer.height);
        while (y < window.size.y) : (y += layer.height) {
            batch.draw(layer.image, layer.offset.addXY(0, y));
        }
    }

    if (layer.repeatX) {
        const posX = zhu.camera.position.x * layer.parallaxX;
        var x = -@mod(posX, layer.width);
        while (x < window.size.x) : (x += layer.width) {
            batch.draw(layer.image, layer.offset.addXY(x, 0));
        }
    }
}
