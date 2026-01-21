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
    offsetx: i32 = 0,
    offsety: i32 = 0,

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

    gid: ?u32 = null, // tile object 才有

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

pub const TileSet = struct {
    columns: u32 = 0,
    image: []const u8 = &.{},
    imageheight: ?u32 = null,
    imagewidth: ?u32 = null,
    margin: u32 = 0,
    name: []const u8,
    spacing: u32 = 0,
    tilecount: u32,
    tiledversion: []const u8,
    tileheight: u32,
    tilewidth: u32,
    tiles: []Tile = &.{},
    objectalignment: []const u8 = &.{},
    grid: ?Grid = null,
    type: ?[]const u8 = null,
    version: ?[]const u8 = null,
};

pub const Tile = struct {
    id: u32,
    image: []const u8 = &.{},
    properties: []Property = &.{},
    imageheight: u32 = 0,
    imagewidth: u32 = 0,
    width: u32 = 0,
    height: u32 = 0,
    probability: f32 = 1,
    objectgroup: ?ObjectGroup = null,
    x: u32 = 0,
    y: u32 = 0,
};

pub const ObjectGroup = struct {
    id: u32 = 0,
    draworder: []const u8 = &.{},
    name: []const u8 = &.{},
    objects: []TiledObject = &.{},
    opacity: f32 = 1,
    type: []const u8 = &.{},
    visible: bool = true,
    x: i32 = 0,
    y: i32 = 0,
};

pub const PropertyValue = union(enum) {
    bool_value: bool,
    int_value: i64,
    float_value: f64,
    string_value: []const u8,
};

pub const Property = struct {
    name: []const u8,
    type: []const u8,
    value: std.json.Value,
};

pub const Grid = struct {
    height: u32,
    orientation: []const u8,
    width: u32,
};

pub const Animation = struct {
    duration: u32,
    tileid: u32,
};
