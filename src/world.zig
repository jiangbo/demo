const std = @import("std");

const window = @import("zhu").window;
const gfx = @import("zhu").gfx;
const camera = @import("zhu").camera;
const math = @import("zhu").math;

var playerTexture: gfx.Texture = undefined;
var mapTexture: gfx.Texture = undefined;

const Map = struct {
    indexes: []const u16,
    items: []const struct { index: u16, item: u16 },
};

const map: Map = @import("zon/map.zon");

var tiles: [500]camera.Vertex = undefined;
var tileIndex: usize = 0;

const FrameAnimation = gfx.FixedFrameAnimation(3, 0.1);
const Animation = std.EnumArray(math.FourDirection, FrameAnimation);

var playerAnimation: Animation = undefined;
var playerDirection: math.FourDirection = .up;
var playerPosition: math.Vector = .init(180, 164);

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

    playerAnimation = createAnimation("assets/pic/player.png");

    // window.playMusic("assets/voc/back.ogg");
}

fn getAreaFromIndex(index: usize) gfx.Rectangle {
    const row: f32 = @floatFromInt(index / 20);
    const col: f32 = @floatFromInt(index % 20);
    return .init(.init(col * 32, row * 32), .init(32, 32));
}

fn createAnimation(path: [:0]const u8) Animation {
    var animation = Animation.initUndefined();

    const texture = gfx.loadTexture(path, .init(96, 192));
    var tex = texture.subTexture(.init(.zero, .init(96, 48)));
    animation.set(.down, FrameAnimation.init(tex));

    tex = texture.subTexture(.init(.init(0, 48), .init(96, 48)));
    animation.set(.left, FrameAnimation.init(tex));

    tex = texture.subTexture(.init(.init(0, 96), .init(96, 48)));
    animation.set(.right, FrameAnimation.init(tex));

    tex = texture.subTexture(.init(.init(0, 144), .init(96, 48)));
    animation.set(.up, FrameAnimation.init(tex));
    return animation;
}

pub fn update(delta: f32) void {
    _ = delta;
}

pub fn enter() void {}

pub fn exit() void {}

pub fn render() void {
    camera.drawVertex(mapTexture, tiles[0..tileIndex]);

    const animation = playerAnimation.get(playerDirection);
    camera.draw(animation.currentTexture(), playerPosition);
}
