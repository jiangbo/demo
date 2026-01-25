const std = @import("std");

const assets = @import("../assets.zig");
const graphics = @import("../graphics.zig");
const math = @import("../math.zig");

pub const TilePosition = struct { x: u32, y: u32 };
const Vector2 = math.Vector2;
const Rect = math.Rect;

pub const Map = struct {
    height: u32,
    width: u32,

    tileSize: graphics.Vector2,
    layers: []const Layer,
    tileSetRefs: []const TileSetRef,

    tileSets: []const TileSet = &.{},

    pub fn size(self: Map) Vector2 {
        return self.tilePositionToWorld(self.width, self.height);
    }

    pub fn tilePositionToWorld(self: Map, x: usize, y: usize) Vector2 {
        const floatX: f32 = @floatFromInt(x);
        return self.tileSize.mul(.xy(floatX, @floatFromInt(y)));
    }

    pub fn worldToTilePosition(self: Map, pos: Vector2) TilePosition {
        const tilePos = pos.div(self.tileSize).floor();
        const x: u32 = @intFromFloat(tilePos.x);
        return .{ .x = x, .y = @intFromFloat(tilePos.y) };
    }

    pub fn worldToTileIndex(self: Map, pos: Vector2) usize {
        const tilePos = self.worldToTilePosition(pos);
        if (tilePos.x < 0 or tilePos.y < 0) return 0;
        if (tilePos.x >= self.width) return 0;
        if (tilePos.y >= self.height) return 0;
        return tilePos.y * self.width + tilePos.x;
    }

    pub fn tileIndexToWorld(self: Map, index: usize) Vector2 {
        const x: f32 = @floatFromInt(index % self.width);
        const y: f32 = @floatFromInt(index / self.width);
        return self.tileSize.mul(.xy(x, y));
    }

    pub fn getTileSetByRef(self: Map, ref: TileSetRef) TileSet {
        for (self.tileSets) |ts| if (ts.id == ref.id) return ts;
        unreachable;
    }

    pub fn getTileSetRefByGid(self: Map, gid: u32) TileSetRef {
        for (self.tileSetRefs) |ref| {
            if (gid < ref.max) return ref;
        } else unreachable;
    }

    pub fn getTileSetByGid(self: Map, gid: u32) TileSet {
        return self.getTileSetByRef(self.getTileSetRefByGid(gid));
    }

    pub fn getTileByGId(self: Map, gid: u32) Tile {
        for (self.tileSetRefs) |ref| {
            if (gid < ref.max) {
                const tileSet = self.getTileSetByRef(ref);
                const id = gid - ref.firstGid;
                for (tileSet.tiles) |tile| {
                    if (id == tile.id) return tile;
                }
            }
        } else unreachable;
    }

    pub fn tileArea(self: Map, index: u32, columns: u32) Rect {
        const x: f32 = @floatFromInt(index % columns);
        const y: f32 = @floatFromInt(index / columns);
        return .init(self.tileSize.mul(.xy(x, y)), self.tileSize);
    }
};
pub const TileSetRef = struct { id: u32, firstGid: u32, max: u32 };

pub const LayerEnum = enum { image, tile, object };

pub const Layer = struct {
    id: u32,
    name: []const u8,
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

pub const PropertyEnum = enum {
    string,
    int,
    float,
    bool,
};

pub const PropertyValue = union(PropertyEnum) {
    string: []const u8, // 字符串值
    int: i32, // 整数值
    float: f32, // 浮点数值
    bool: bool, // 布尔值
};

pub const Property = struct {
    name: []const u8, // 属性名称
    value: PropertyValue, // 具体的属性值
};

pub const TileSet = struct {
    id: u32,
    columns: u32,
    tileCount: i32,
    image: u32,
    tiles: []const Tile,

    pub fn getTileByLocalId(self: TileSet, id: u32) ?Tile {
        for (self.tiles) |tile| {
            if (id == tile.id) return tile;
        } else return null;
    }
};

pub const Tile = struct {
    id: i32,
    image: u32,
    objectGroup: ?ObjectGroup = null,
    properties: []const Property,
};

pub const ObjectGroup = struct {
    visible: bool, // 是否可见
    objects: []const Object, // 物体数组 (物体层用)
};

pub const Object = struct {
    gid: u32 = 0,
    position: Vector2, // 像素坐标
    size: Vector2, // 像素宽高
    point: bool = false, // 是否为点物体
    properties: []const Property = &.{}, // 物体自定义属性
    rotation: f32, // 顺时针旋转角度
};
