const std = @import("std");

pub const Map = struct {
    height: u32,
    width: u32,

    tileWidth: u32,
    tileHeight: u32,
    layers: []const Layer,
    tileSets: []const TileSetRef,
};

pub const LayerEnum = enum { image, tile, object };

pub const Layer = struct {
    id: u32,
    image: u32,
    type: LayerEnum,

    width: u32 = 0,
    height: u32 = 0,
    opacity: f32,
    visible: bool,

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
    id: u32,
    name: []const u8,
    type: []const u8,

    gid: u32,

    x: f32,
    y: f32,

    width: f32,
    height: f32,

    rotation: f32,
    visible: bool,
};

pub const TileSetRef = struct { firstGid: u32, source: []const u8 };
