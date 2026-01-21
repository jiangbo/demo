const std = @import("std");

const graphics = @import("../graphics.zig");
const math = @import("../math.zig");

const Vector2 = math.Vector2;
const Rect = math.Rect;

pub const Map = struct {
    height: u32,
    width: u32,

    tileSize: graphics.Vector2,
    layers: []const Layer,
    tileSets: []const TileSet,
};

pub const LayerEnum = enum { image, tile, object };

pub const Layer = struct {
    id: u32,
    image: u32,
    type: LayerEnum,

    width: f32 = 0,
    height: f32 = 0,

    offset: Vector2,

    // tile 层特有
    data: []const u32,

    // 对象层特有
    objects: []const Object,

    // 图片层
    parallaxX: f32 = 1.0,
    parallaxY: f32 = 1.0,
    repeatX: bool = false,
    repeatY: bool = false,
};

pub const Object = struct {
    gid: u32,
    position: Vector2,
    size: Vector2,
    rotation: f32,
};

pub const TileSet = struct {
    columns: u32,
    min: u32,
    max: u32,
    images: []const u32,
};

pub const Tile = struct {
    image: graphics.Image,
    position: graphics.Vector2,
};

pub fn tileArea(index: u32, size: Vector2, columns: u32) Rect {
    const x: f32 = @floatFromInt(index % columns);
    const y: f32 = @floatFromInt(index / columns);
    return Rect.init(size.mul(.xy(x, y)), size);
}
