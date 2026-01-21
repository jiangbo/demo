const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const batch = zhu.batch;
const tiled = zhu.extend.tiled;

const level1: tiled.Map = @import("zon/level1.zon");

pub fn draw() void {
    for (level1.layers) |*layer| {
        switch (layer.type) {
            .image => drawImageLayer(layer),
            else => {},
        }
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
