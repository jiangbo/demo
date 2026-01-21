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

        const image = zhu.assets.getImage(layer.image);
        const width: u32 = @intFromFloat(layer.width);

        for (layer.data, 0..) |tileIndex, index| {
            if (tileIndex == 0) continue;
            if (tileIndex > 575) {
                std.log.info("tile index: {}", .{tileIndex});
                continue;
            }

            const x: f32 = @floatFromInt(index % width);
            const y: f32 = @floatFromInt(index / width);

            const area = computeTileArea(tileIndex - 1, 16, 16, 25);
            tiles.append(zhu.assets.allocator, .{
                .image = image.sub(area),
                .position = .xy(x * 16, y * 16),
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

fn computeTileArea(index: u32, tileWidth: f32, tileHeight: f32, width: u32) zhu.Rect {
    const x: f32 = @floatFromInt(index % width);
    const y: f32 = @floatFromInt(index / width);
    return zhu.Rect{
        .min = .xy(x * tileWidth, y * tileHeight),
        .size = .xy(tileWidth, tileHeight),
    };
}
