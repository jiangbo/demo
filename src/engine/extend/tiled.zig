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

    pub fn tileRect(self: Map, index: usize) Rect {
        return .init(self.tileIndexToWorld(index), self.tileSize);
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

    /// 返回矩形覆盖到的地图内瓦片，范围会按地图边界裁剪
    pub fn tilesInRect(self: Map, rect: Rect) TileRectIter {
        std.debug.assert(rect.size.y > 0 and rect.size.x > 0);

        const rawMin = self.worldToTilePosition(rect.min);
        const max = rect.max().sub(.square(math.epsilon));
        const rawMax = self.worldToTilePosition(max);

        const width: i32 = @intCast(self.width);
        const height: i32 = @intCast(self.height);

        const min = Position.xy(@max(rawMin.x, 0), @max(rawMin.y, 0));
        const maxX = @min(rawMax.x, width - 1);
        const maxY = @min(rawMax.y, height - 1);
        if (min.x > maxX or min.y > maxY) return .{};

        return .{
            .width = width,
            .min = min,
            .max = .xy(maxX, maxY),
            .current = min,
        };
    }

    pub fn grid(self: *const Map, comptime T: type, data: []const T) Grid(T) {
        return .{ .map = self, .data = data };
    }

    pub fn getTileSetRefByGid(self: Map, gid: u32) TileSetRef {
        std.debug.assert(gid != 0);
        return self.tileSetRefs[(gid >> 24) - 1];
    }

    pub fn getTileSetByGid(self: Map, gid: u32) TileSet {
        return getTileSetByRef(self.getTileSetRefByGid(gid));
    }

    pub fn getTileByGid(self: Map, gid: u32) ?*const Tile {
        const ref = self.getTileSetRefByGid(gid);
        const tileSet = getTileSetByRef(ref);
        return tileSet.tileByLocalId(gid & 0x00FFFFFF);
    }

    pub fn getImageByGid(self: Map, gid: u32) graphics.Image {
        const ref = self.getTileSetRefByGid(gid);
        const tileSet = getTileSetByRef(ref);
        const localId = gid & 0x00FFFFFF;

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

    pub fn getAnimationByGid(self: Map, gid: u32) ?graphics.Animation {
        const ref = self.getTileSetRefByGid(gid);
        const tileSet = getTileSetByRef(ref);
        const localId = gid & 0x00FFFFFF;
        if (tileSet.tileByLocalId(localId)) |tile| {
            if (tile.animation.len == 0) return null;
            return graphics.Animation.init(
                assets.getImage(tileSet.image).?,
                tileSet.tileSize,
                tile.animation,
            );
        } else return null;
    }
};

pub fn Scan(comptime T: type) type {
    return struct {
        dest: f32 = 0,
        touch: f32 = 0,
        state: State = .{},

        const State = struct {
            data: []const T = &.{},
            index: i32 = 0,
            remaining: u32 = 0,
            step: i32 = 1,
        };

        pub fn reversed(self: @This()) @This() {
            var scan = self;
            if (scan.state.remaining > 0) {
                const last: i32 = @intCast(scan.state.remaining - 1);
                scan.state.index += last * scan.state.step;
                scan.state.step = -scan.state.step;
            }
            return scan;
        }

        pub fn next(self: *@This()) ?T {
            if (self.state.remaining == 0) return null;

            const index = self.state.index;
            self.state.index += self.state.step;
            self.state.remaining -= 1;

            std.debug.assert(index >= 0);
            const i: usize = @intCast(index);
            std.debug.assert(i < self.state.data.len);
            return self.state.data[i];
        }
    };
}

pub fn Grid(comptime T: type) type {
    return struct {
        map: *const Map,
        data: []const T = &.{},

        const Self = @This();
        pub const TileScan = Scan(T);

        const Edge = struct {
            fixed: i32,
            touch: f32,
        };

        pub fn tileAt(self: *const Self, pos: Position) ?T {
            self.assertValid();
            const index = self.map.tilePositionToIndex(pos) orelse return null;
            return self.data[index];
        }

        /// 扫描 X 轴移动后的前沿瓦片，返回顺序固定为从上到下
        pub fn scanX(self: *const Self, rect: Rect, dx: f32) TileScan {
            self.assertValid();
            std.debug.assert(rect.size.x > 0 and rect.size.y > 0);

            const dest = rect.min.x + dx;
            if (dx == 0) return .{ .dest = dest };

            const r0 = tileCoord(rect.min.y, self.map.tileSize.y);
            const bottom = rect.min.y + rect.size.y - math.epsilon;
            const r1 = tileCoord(bottom, self.map.tileSize.y);
            const rows = clipRange(r0, r1, self.map.height);

            const edge: Edge = if (dx > 0) right_edge: {
                // 向右时固定目标右边缘所在列。
                const right = dest + rect.size.x - math.epsilon;
                const col = tileCoord(right, self.map.tileSize.x);
                const left = @as(f32, @floatFromInt(col)) *
                    self.map.tileSize.x;
                break :right_edge .{
                    .fixed = col,
                    .touch = left - rect.size.x,
                };
            } else left_edge: {
                // 向左时固定目标左边缘所在列。
                const col = tileCoord(dest, self.map.tileSize.x);
                const right = (@as(f32, @floatFromInt(col)) + 1) *
                    self.map.tileSize.x;
                break :left_edge .{ .fixed = col, .touch = right };
            };

            const remaining = if (inRange(edge.fixed, self.map.width))
                rows.count
            else
                0;
            const width: i32 = @intCast(self.map.width);
            const index = if (remaining > 0)
                rows.first * width + edge.fixed
            else
                0;
            return .{
                .dest = dest,
                .touch = edge.touch,
                .state = .{
                    .data = self.data,
                    .index = index,
                    .remaining = remaining,
                    .step = width,
                },
            };
        }

        /// 扫描 Y 轴移动后的前沿瓦片，返回顺序固定为从左到右
        pub fn scanY(self: *const Self, rect: Rect, dy: f32) TileScan {
            self.assertValid();
            std.debug.assert(rect.size.x > 0 and rect.size.y > 0);

            const dest = rect.min.y + dy;
            if (dy == 0) return .{ .dest = dest };

            const c0 = tileCoord(rect.min.x, self.map.tileSize.x);
            const right = rect.min.x + rect.size.x - math.epsilon;
            const c1 = tileCoord(right, self.map.tileSize.x);
            const cols = clipRange(c0, c1, self.map.width);

            const edge: Edge = if (dy > 0) bottom_edge: {
                // 向下时固定目标下边缘所在行。
                const targetBottom = dest + rect.size.y - math.epsilon;
                const row = tileCoord(targetBottom, self.map.tileSize.y);
                const top = @as(f32, @floatFromInt(row)) * self.map.tileSize.y;
                break :bottom_edge .{
                    .fixed = row,
                    .touch = top - rect.size.y,
                };
            } else top_edge: {
                // 向上时固定目标上边缘所在行。
                const row = tileCoord(dest, self.map.tileSize.y);
                const bottom = (@as(f32, @floatFromInt(row)) + 1) *
                    self.map.tileSize.y;
                break :top_edge .{ .fixed = row, .touch = bottom };
            };

            const remaining = if (inRange(edge.fixed, self.map.height))
                cols.count
            else
                0;
            const width: i32 = @intCast(self.map.width);
            const index = if (remaining > 0)
                edge.fixed * width + cols.first
            else
                0;
            return .{
                .dest = dest,
                .touch = edge.touch,
                .state = .{
                    .data = self.data,
                    .index = index,
                    .remaining = remaining,
                },
            };
        }

        fn assertValid(self: *const Self) void {
            std.debug.assert(self.map.tileSize.x > 0);
            std.debug.assert(self.map.tileSize.y > 0);
            const total = @as(usize, self.map.width) *
                @as(usize, self.map.height);
            std.debug.assert(self.data.len >= total);
        }
    };
}

pub const TileRectIter = struct {
    width: i32 = 0,
    min: Position = .xy(0, 0),
    max: Position = .xy(-1, -1),
    current: Position = .xy(0, 0),

    pub fn next(self: *TileRectIter) ?usize {
        if (self.current.y > self.max.y) return null;

        const i = self.current.y * self.width + self.current.x;
        self.current.x += 1;
        if (self.current.x > self.max.x) {
            self.current.x = self.min.x;
            self.current.y += 1;
        }
        return @intCast(i);
    }
};

const Range = struct {
    first: i32 = 0,
    count: u32 = 0,
};

fn clipRange(first: i32, last: i32, limit: u32) Range {
    if (last < first or limit == 0) return .{};
    if (last < 0) return .{};

    const limitI: i32 = @intCast(limit);
    if (first >= limitI) return .{};

    const clippedFirst = @max(first, 0);
    const clippedLast = @min(last, limitI - 1);
    return .{
        .first = clippedFirst,
        .count = @intCast(clippedLast - clippedFirst + 1),
    };
}

fn inRange(index: i32, limit: u32) bool {
    if (index < 0) return false;
    return @as(u32, @intCast(index)) < limit;
}

fn tileCoord(value: f32, size: f32) i32 {
    std.debug.assert(size > 0);
    return @intFromFloat(@floor(value / size));
}

pub const TileSetRef = struct { id: u32 };

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

    pub fn hasProperty(self: Tile, name: []const u8) bool {
        for (self.properties) |property| {
            if (property.is(name)) return true;
        }
        return false;
    }

    pub fn getProperty(self: Tile, name: []const u8, T: type) ?T {
        for (self.properties) |property| {
            if (property.is(name)) return property.value.get(T);
        }
        return null;
    }
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

    pub fn topLeft(self: Object) Vector2 {
        if (self.gid == 0) return self.position;
        return self.position.addY(-self.size.y);
    }

    pub fn rect(self: Object) Rect {
        return .init(self.topLeft(), self.size);
    }

    pub fn hasProperty(self: Object, name: []const u8) bool {
        for (self.properties) |property| {
            if (property.is(name)) return true;
        }
        return false;
    }

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

pub fn getTileSetById(id: assets.Id) TileSet {
    for (tileSets) |ts| if (ts.id == id) return ts;
    unreachable;
}

pub fn getTileSetByRef(ref: TileSetRef) TileSet {
    return getTileSetById(ref.id);
}

pub fn getTileByImageId(id: graphics.ImageId) Tile {
    for (tileSets) |ts| {
        for (ts.tiles) |tile| if (tile.id == id) return tile;
    } else unreachable;
}
