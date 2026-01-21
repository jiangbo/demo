const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const batch = zhu.batch;
const tiled = zhu.extend.tiled;

const level1: tiled.Map = @import("zon/level1.zon");
var tiles: std.ArrayList(tiled.Tile) = .empty;

pub fn init() void {
    for (level1.layers) |layer| {
        if (layer.type != .tile) continue;

        const width: u32 = @intFromFloat(layer.width);

        for (layer.data, 0..) |tileIndex, index| {
            if (tileIndex == 0) continue;

            const tileSet = blk: for (level1.tileSets) |tileSet| {
                if (tileIndex < tileSet.max) break :blk tileSet;
            } else unreachable;

            var image: zhu.graphics.Image = undefined;
            const i = tileIndex - tileSet.min;
            if (tileSet.columns == 0) {
                image = zhu.assets.getImage(tileSet.images[i]);
            } else {
                const area = tiled.imageArea(i, level1.tileSize, tileSet.columns);
                image = zhu.assets.getImage(tileSet.images[0]).sub(area);
            }

            const x: f32 = @floatFromInt(index % width);
            const y: f32 = @floatFromInt(index / width);

            tiles.append(zhu.assets.allocator, .{
                .image = image,
                .position = level1.tileSize.mul(.xy(x, y)),
            }) catch @panic("oom, can't append tile");
        }
    }
}

pub fn deinit() void {
    tiles.deinit(zhu.assets.allocator);
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
            batch.draw(layer.image, .xy(0, y));
        }
    }

    if (layer.repeatX) {
        const posX = zhu.camera.position.x * layer.parallaxX;
        var x = -@mod(posX, layer.width);
        while (x < window.size.x) : (x += layer.width) {
            batch.draw(layer.image, .xy(x, 0));
        }
    }
}
