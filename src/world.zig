const std = @import("std");

const window = @import("zhu").window;
const gfx = @import("zhu").gfx;
const camera = @import("zhu").camera;

var playerTexture: gfx.Texture = undefined;
var mapTexture: gfx.Texture = undefined;

const Map = struct {
    indexes: []const u16,
    items: []const struct { index: u16, item: u16 },
};

const map: Map = @import("zon/map.zon");

var tiles: [500]camera.Vertex = undefined;
var tileIndex: usize = 0;

pub fn init() void {
    playerTexture = gfx.loadTexture("assets/pic/player.png", .init(96, 192));
    mapTexture = gfx.loadTexture("assets/pic/maps.png", .init(640, 1536));

    // 背景
    for (map.indexes, 0..) |mapIndex, index| {
        if (mapIndex == std.math.maxInt(u16)) continue;

        const tile = mapTexture.subTexture(getAreaFromIndex(mapIndex));
        tiles[tileIndex] = .{
            .position = getAreaFromIndex(index).min,
            .size = .init(32, 32),
            .texture = tile.area.toVector4(),
        };
        tileIndex += 1;
    }

    // 装饰
    for (map.items) |item| {
        const tile = mapTexture.subTexture(getAreaFromIndex(item.item));
        tiles[tileIndex] = .{
            .position = getAreaFromIndex(item.index).min,
            .size = .init(32, 32),
            .texture = tile.area.toVector4(),
        };
        tileIndex += 1;
    }

    // window.playMusic("assets/voc/back.ogg");
}

fn getAreaFromIndex(index: usize) gfx.Rectangle {
    const row: f32 = @floatFromInt(index / 20);
    const col: f32 = @floatFromInt(index % 20);
    return .init(.init(col * 32, row * 32), .init(32, 32));
}

pub fn update(delta: f32) void {
    _ = delta;
}

pub fn enter() void {}

pub fn exit() void {}

pub fn render() void {
    camera.drawVertex(mapTexture, tiles[0..tileIndex]);
    // camera.draw(playerTexture, .init(100, 100));
}
