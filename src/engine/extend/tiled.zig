const std = @import("std");

const assets = @import("../assets.zig");
const graphics = @import("../graphics.zig");
const math = @import("../math.zig");

pub const Position = struct {
    x: i32,
    y: i32,

    pub fn xy(x: i32, y: i32) Position {
        return .{ .x = x, .y = y };
    }
};
const Vector2 = math.Vector2;
const Rect = math.Rect;

pub const Map = struct {
    height: u32,
    width: u32,

    backgroundColor: ?graphics.Color = null,
    tileSize: graphics.Vector2,
    layers: []const Layer,
    tileSetRefs: []const TileSetRef,

    pub fn size(self: Map) Vector2 {
        const width: i32 = @intCast(self.width);
        const height: i32 = @intCast(self.height);
        return self.tilePositionToWorld(.xy(width, height));
    }

    pub fn tilePositionToIndex(self: Map, pos: Position) ?usize {
        if (pos.x < 0 or pos.y < 0) return null;
        if (pos.x >= self.width or pos.y >= self.height) return null;
        return @intCast(pos.y * @as(i32, @intCast(self.width)) + pos.x);
    }

    pub fn tilePositionToWorld(self: Map, pos: Position) Vector2 {
        const floatX: f32 = @floatFromInt(pos.x);
        return self.tileSize.mul(.xy(floatX, @floatFromInt(pos.y)));
    }

    pub fn tileIndexToWorld(self: Map, index: usize) Vector2 {
        const x: f32 = @floatFromInt(index % self.width);
        const y: f32 = @floatFromInt(index / self.width);
        return self.tileSize.mul(.xy(x, y));
    }

    pub fn worldToTileStart(self: Map, pos: Vector2) Vector2 {
        const tilePos = self.worldToTilePosition(pos);
        return self.tilePositionToWorld(tilePos);
    }

    pub fn worldToTilePosition(self: Map, pos: Vector2) Position {
        const tilePos = pos.div(self.tileSize).floor();
        const x: i32 = @intFromFloat(tilePos.x);
        return .{ .x = x, .y = @intFromFloat(tilePos.y) };
    }

    pub fn worldToTileIndex(self: Map, pos: Vector2) ?usize {
        const tilePos = self.worldToTilePosition(pos);
        return self.tilePositionToIndex(tilePos);
    }

    pub fn tileSetRefByGid(self: Map, gid: u32) TileSetRef {
        std.debug.assert(gid != 0);
        for (self.tileSetRefs) |ref| {
            if (gid >= ref.firstGid and gid < ref.max) return ref;
        } else unreachable;
    }

    pub fn tileSetByGid(self: Map, gid: u32) TileSet {
        return tileSetByRef(self.tileSetRefByGid(gid));
    }

    pub fn tileByGid(self: Map, gid: u32) ?*const Tile {
        const ref = self.tileSetRefByGid(gid);
        const tileSet = tileSetByRef(ref);
        return tileSet.tileByLocalId(gid - ref.firstGid);
    }

    pub fn imageByGid(self: Map, gid: u32) graphics.Image {
        const ref = self.tileSetRefByGid(gid);
        const tileSet = tileSetByRef(ref);
        const localId = gid - ref.firstGid;

        if (tileSet.columns == 0) {
            const tile = tileSet.tileByLocalId(localId).?;
            return assets.getImage(tile.id).?;
        }

        const x: f32 = @floatFromInt(localId % tileSet.columns);
        const y: f32 = @floatFromInt(localId / tileSet.columns);
        const position = tileSet.tileSize.mul(.xy(x, y));
        const area = Rect.init(position, tileSet.tileSize);
        return assets.getImage(tileSet.image).?.sub(area);
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

    pub fn isNamed(self: Layer, name: []const u8) bool {
        return std.mem.eql(u8, self.name, name);
    }
};

pub const PropertyEnum = enum {
    string,
    int,
    float,
    bool,
    object,
    class,
};

pub const PropertyValue = union(PropertyEnum) {
    string: []const u8, // 字符串值
    int: i32, // 整数值
    float: f32, // 浮点数值
    bool: bool, // 布尔值
    object: i32, // 引用物体 ID
    class: ClassProperty, // Tiled 1.8+ 类属性

    pub fn get(self: PropertyValue, comptime T: type) ?T {
        if (T == []const u8) return self.string;
        if (T == bool) return self.bool;
        if (T == ClassProperty) return self.class;
        if (@typeInfo(T) == .int) return @intCast(self.int);
        if (@typeInfo(T) == .float) return @floatCast(self.float);
        @compileError("unsupported property type: " ++ @typeName(T));
    }
};

pub const ClassProperty = struct {
    type: []const u8, // 类名，例如 Spotlight
    properties: []const Property, // 类内部成员

    pub fn is(self: ClassProperty, typeName: []const u8) bool {
        return std.mem.eql(u8, self.type, typeName);
    }

    pub fn get(self: ClassProperty, name: []const u8, T: type) ?T {
        for (self.properties) |property| {
            if (property.is(name)) return property.value.get(T);
        }
        return null;
    }
};

pub const Property = struct {
    name: []const u8, // 属性名称
    value: PropertyValue, // 具体的属性值

    pub fn is(self: Property, name: []const u8) bool {
        return std.mem.eql(u8, self.name, name);
    }
};

pub const TileSet = struct {
    id: u32,
    columns: u32,
    tileCount: i32,
    image: u32,
    tileSize: graphics.Vector2,
    tiles: []const Tile,

    pub fn tileByLocalId(self: TileSet, id: u32) ?*const Tile {
        if (self.columns == 0) return &self.tiles[id];
        for (self.tiles) |*tile| {
            if (id == tile.id) return tile;
        } else return null;
    }
};

pub const Tile = struct {
    id: u32,
    objectGroup: ?ObjectGroup = null,
    properties: []const Property,
    animation: []const graphics.Frame = &.{},
};

pub const ObjectGroup = struct {
    visible: bool, // 是否可见
    objects: []const Object, // 物体数组 (物体层用)
};

pub const ObjectExtend = packed struct(u8) {
    flipX: bool = false, // 水平翻转
    flipY: bool = false, // 垂直翻转
    rotation: bool = false, // 旋转90度
    padding: u5 = 0,
};

pub const Object = struct {
    id: u32,
    gid: u32,
    name: []const u8,
    type: []const u8,
    position: Vector2, // 像素坐标
    size: Vector2, // 像素宽高
    point: bool, // 是否为点物体
    properties: []const Property, // 物体自定义属性
    extend: ObjectExtend, // 扩展信息

    pub fn getProperty(self: Object, name: []const u8, T: type) ?T {
        for (self.properties) |property| {
            if (property.is(name)) return property.value.get(T);
        }
        return null;
    }

    pub fn getClass(self: Object, name: []const u8) ?ClassProperty {
        return self.getProperty(name, ClassProperty);
    }

    pub fn isNamed(self: Object, name: []const u8) bool {
        return std.mem.eql(u8, self.name, name);
    }

    pub fn isType(self: Object, typeName: []const u8) bool {
        return std.mem.eql(u8, self.type, typeName);
    }
};

pub var backgroundColor: ?graphics.Color = null;
var tileSets: []const TileSet = &.{};

pub fn init(ts: []const TileSet) void {
    tileSets = ts;
}

pub fn tileSetById(id: assets.Id) TileSet {
    for (tileSets) |ts| if (ts.id == id) return ts;
    unreachable;
}

pub fn tileSetByRef(ref: TileSetRef) TileSet {
    return tileSetById(ref.id);
}

pub fn tileByImageId(id: graphics.ImageId) Tile {
    for (tileSets) |ts| {
        for (ts.tiles) |tile| if (tile.id == id) return tile;
    } else unreachable;
}
