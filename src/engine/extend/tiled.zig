const std = @import("std");

const assets = @import("../assets.zig");
const graphics = @import("../graphics.zig");
const math = @import("../math.zig");

pub const TilePosition = struct { x: u32, y: u32 };
const Vector2 = math.Vector2;
const Rect = math.Rect;

pub const TileMap = struct {
    height: u32,
    width: u32,

    tileSize: graphics.Vector2,
    layers: []const Layer,
    tileSetRefs: []const TileSetRef,
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

pub const Map = struct {
    map: TileMap,
    tileSets: []const TileSet,

    pub fn init(map: TileMap, tileSets: []const TileSet) Map {
        return Map{ .map = map, .tileSets = tileSets };
    }

    pub fn getTileSetByRef(self: Map, ref: TileSetRef) TileSet {
        for (self.tileSets) |ts| if (ts.id == ref.id) return ts;
        unreachable;
    }

    pub fn getTileSetRefByGid(self: Map, gid: u32) TileSetRef {
        for (self.map.tileSetRefs) |ref| {
            if (gid < ref.max) return ref;
        } else unreachable;
    }

    pub fn getTileSetByGid(self: Map, gid: u32) TileSet {
        return self.getTileSetByRef(self.getTileSetRefByGid(gid));
    }

    pub fn getTileByGId(self: Map, gid: u32) Tile {
        for (self.map.tileSetRefs) |ref| {
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
        const size = self.map.tileSize;
        return Rect.init(size.mul(.xy(x, y)), size);
    }
};
