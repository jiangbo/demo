const std = @import("std");

pub const TiledMap = struct {
    compressionlevel: ?i32,
    height: u32,
    width: u32,

    infinite: bool,

    layers: []Layer,

    nextlayerid: u32,
    nextobjectid: u32,

    orientation: []const u8, // "orthogonal"
    renderorder: []const u8, // "right-down"

    tiledversion: []const u8,
    version: []const u8,

    tilewidth: u32,
    tileheight: u32,

    tilesets: []TilesetRef,

    type: []const u8, // "map"
};

pub const Layer = struct {
    id: u32,
    name: []const u8,
    type: []const u8,

    opacity: f32,
    visible: bool,

    x: i32,
    y: i32,

    // imagelayer
    image: ?[]const u8 = null,
    imagewidth: ?u32 = null,
    imageheight: ?u32 = null,
    parallaxx: ?f32 = null,
    parallaxy: ?f32 = null,
    repeatx: ?bool = null,
    repeaty: ?bool = null,
    offsetx: ?i32 = null,
    offsety: ?i32 = null,

    // tilelayer
    width: ?u32 = null,
    height: ?u32 = null,
    data: ?[]u32 = null,

    // objectgroup
    draworder: ?[]const u8 = null,
    objects: ?[]TiledObject = null,
};

pub const TiledObject = struct {
    id: u32,
    name: []const u8,
    type: []const u8,

    gid: ?u32, // tile object 才有

    x: f32,
    y: f32,

    width: f32,
    height: f32,

    rotation: f32,
    visible: bool,
};

pub const TilesetRef = struct {
    firstgid: u32,
    source: []const u8, // "tileset.tsj"
};
