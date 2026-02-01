const std = @import("std");

const parsed = @import("parsed.zig");
const tiled = @import("tiled.zig");

const Vector2 = struct { x: f32, y: f32 };

const TileSet = struct {
    id: u32,
    columns: u32,
    tileCount: u32,
    image: u32,
    tiles: []const Tile,
};

const zero = Vector2{ .x = 0, .y = 0 };
const one = Vector2{ .x = 1, .y = 1 };
pub const Rect = struct { min: Vector2 = zero, size: Vector2 = one };
pub const Frame = struct { rect: Rect, duration: f32 = 0.1 };
const Tile = struct {
    id: u32,
    objectGroup: ?ObjectGroup = null,
    properties: []const parsed.Property,
    animation: []const Frame,
};

pub const ObjectGroup = struct {
    visible: bool, // 是否可见
    objects: []const Object, // 物体数组 (物体层用)
    // properties: ?[]const parsed.Property = null, // 图层自定义属性
};

const ObjectExtend = packed struct(u8) {
    flipX: bool = false, // 水平翻转
    flipY: bool = false, // 垂直翻转
    rotation: bool = false, // 旋转90度
    padding: u5 = 0,
};

pub const Object = struct {
    gid: u32 = 0,
    position: Vector2, // 像素坐标
    size: Vector2, // 像素宽高
    point: bool = false, // 是否为点物体
    properties: []const parsed.Property = &.{}, // 物体自定义属性
    extend: ObjectExtend, // 扩展信息
};

var allocator: std.mem.Allocator = undefined;
pub fn main() !void {
    var debug: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug.deinit();
    var arena = std.heap.ArenaAllocator.init(debug.allocator());
    defer arena.deinit();
    allocator = arena.allocator();

    // 必须要指定一个目录
    const args = try std.process.argsAlloc(allocator);
    if (args.len != 2) return error.invalidArgs;
    const path = args[1];

    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var tileSets: std.ArrayListUnmanaged(TileSet) = .empty;

    var it = dir.iterate();
    const max = std.math.maxInt(usize);
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        const name = entry.name;
        if (!std.mem.endsWith(u8, name, ".tsj")) continue;
        const id = std.hash.Fnv1a_32.hash(name);
        std.log.info("====================================================", .{});
        std.log.info("name: {s}, id: {}", .{ name, id });

        const content = try dir.readFileAlloc(allocator, name, max);
        const parse = std.json.parseFromSliceLeaky;
        source = try parse(tiled.Tileset, allocator, content, .{});
        try tileSets.append(allocator, try parseTileSet(id, source));
    }
    std.log.info("====================================================", .{});
    std.mem.sort(TileSet, tileSets.items, {}, struct {
        fn lessThan(_: void, a: TileSet, b: TileSet) bool {
            return a.id < b.id;
        }
    }.lessThan);

    const outFile = try dir.createFile("tile.zon", .{ .truncate = true });
    defer outFile.close();
    var buffer: [4096]u8 = undefined;
    var writer = outFile.writer(&buffer);
    try std.zon.stringify.serialize(tileSets.items, .{}, &writer.interface);
    try writer.interface.flush();
}

const hash = std.hash.Fnv1a_32.hash;
var source: tiled.Tileset = undefined;
fn parseTileSet(id: u32, value: tiled.Tileset) !TileSet {
    var tiles: []Tile = &.{};
    if (value.tiles) |t| {
        if (value.columns == 0) {
            tiles = try parseTilesCollection(t);
        } else {
            tiles = try parseTilesSingle(t);
        }
    }

    if (value.columns > 0) {
        const count = @divExact(value.tilecount, value.columns);
        const fmt = "tileSet: {s} ({}x{} tiles), len: {}";
        std.log.info(fmt, .{ value.name, value.columns, count, tiles.len });
    } else {
        const fmt = "tileSet: {s} ({} tiles - collection), len: {}";
        std.log.info(fmt, .{ value.name, value.tilecount, tiles.len });
    }

    var imageId: u32 = 0;
    if (value.image) |img| {
        const i = std.mem.indexOf(u8, img, "texture").?;
        imageId = hash(img[i..]);
        std.log.info("image: {s}, id: {}", .{ img[i..], imageId });
    }

    return .{
        .id = id,
        .columns = @intCast(value.columns),
        .tileCount = @intCast(value.tilecount),
        .image = imageId,
        .tiles = tiles,
    };
}

fn parseTilesSingle(tiles: []tiled.TileDefinition) ![]Tile {
    const result = try allocator.alloc(Tile, tiles.len);
    for (tiles, 0..) |tile, index| {
        var imageId: u32 = 0;
        if (tile.image) |img| {
            const i = std.mem.indexOf(u8, img, "texture").?;
            imageId = hash(img[i..]);
            std.log.info("image: {s}, id: {}", .{ img[i..], imageId });
        }

        var propertes: []parsed.Property = &.{};
        if (tile.properties) |p| propertes = try parseProperties(p);

        var group: ?ObjectGroup = null;
        if (tile.objectgroup) |g| group = try parseObjectGroup(g);

        result[index] = .{
            .id = tile.id,
            .properties = propertes,
            .objectGroup = group,
            .animation = try parseAnimation(tile.animation),
        };
    }
    return result;
}

fn parseTilesCollection(tiles: []tiled.TileDefinition) ![]Tile {
    const last = tiles[tiles.len - 1];
    const result = try allocator.alloc(Tile, last.id + 1);
    @memset(result, std.mem.zeroes(Tile));

    for (tiles) |tile| {
        var imageId: u32 = 0;
        if (tile.image) |img| {
            const i = std.mem.indexOf(u8, img, "texture").?;
            imageId = hash(img[i..]);
            std.log.info("image: {s}, id: {}", .{ img[i..], imageId });
        }

        var propertes: []parsed.Property = &.{};
        if (tile.properties) |p| propertes = try parseProperties(p);

        var group: ?ObjectGroup = null;
        if (tile.objectgroup) |g| group = try parseObjectGroup(g);

        result[tile.id] = .{
            .id = imageId,
            .properties = propertes,
            .objectGroup = group,
            .animation = try parseAnimation(tile.animation),
        };
    }
    return result;
}

fn parseAnimation(frames: []tiled.Frame) ![]Frame {
    const result = try allocator.alloc(Frame, frames.len);

    for (frames, 0..) |frame, i| {
        result[i] = .{
            .rect = parseRectFromId(frame.tileid),
            .duration = @as(f32, @floatFromInt(frame.duration)) / 1000.0,
        };
    }
    return result;
}

fn parseRectFromId(id: u32) Rect {
    return .{
        .min = .{
            .x = @floatFromInt((id % source.columns) * source.tilewidth),
            .y = @floatFromInt((id / source.columns) * source.tileheight),
        },
        .size = .{
            .x = @floatFromInt(source.tilewidth),
            .y = @floatFromInt(source.tileheight),
        },
    };
}

fn parseObjectGroup(value: tiled.Layer) !ObjectGroup {
    const objects = try parseObjects(value.objects);
    return .{ .visible = value.visible, .objects = objects };
}

fn parseObjects(objects: []tiled.Object) ![]Object {
    const result = try allocator.alloc(Object, objects.len);
    for (objects, 0..) |object, i| {
        result[i] = .{
            .point = object.point,
            .extend = .{},
            .position = .{ .x = object.x, .y = object.y },
            .size = .{ .x = object.width, .y = object.height },
        };
    }
    return result;
}

fn convertPoints(value: ?[]const tiled.Point) !?[]const parsed.Point {
    if (value) |points| {
        const result = try allocator.alloc(parsed.Point, points.len);
        for (points, 0..) |point, i| {
            result[i] = .{ .x = point.x, .y = point.y };
        }
        return result;
    }
    return null;
}

fn convertText(value: ?tiled.Text) !?parsed.Text {
    if (value) |text| {
        return parsed.Text{
            .bold = text.bold,
            .color = text.color,
            .fontFamily = text.fontfamily,
            .halign = text.halign,
            .italic = text.italic,
            .kerning = text.kerning,
            .pixelSize = text.pixelsize,
            .strikeout = text.strikeout,
            .text = text.text,
            .underline = text.underline,
            .valign = text.valign,
            .wrap = text.wrap,
        };
    }
    return null;
}

fn parseProperties(properties: []tiled.Property) ![]parsed.Property {
    const result = try allocator.alloc(parsed.Property, properties.len);
    for (properties, 0..) |property, i| {
        result[i] = .{
            .name = property.name,
            .value = parsePropertyValue(property),
        };
    }
    return result;
}

const toEnum = std.meta.stringToEnum;
fn parsePropertyValue(property: tiled.Property) parsed.PropertyValue {
    return switch (toEnum(parsed.PropertyEnum, property.type).?) {
        .string => .{ .string = property.value.string },
        .int => .{ .int = @intCast(property.value.integer) },
        .float => .{ .float = @floatCast(property.value.float) },
        .bool => .{ .bool = property.value.bool },
        .object => .{ .object = property.value.integer },
    };
}

fn convertTileData(value: ?std.json.Value) ![]u32 {
    if (value) |v| {
        switch (v) {
            .array => return try convertJsonArrayToTiles(v),
            else => {},
        }
    }
    return &.{};
}

fn convertJsonArrayToTiles(value: std.json.Value) ![]u32 {
    return switch (value) {
        .array => |arr| blk: {
            const items = arr.items;
            const result = try allocator.alloc(u32, items.len);
            for (items, 0..) |entry, i| {
                result[i] = switch (entry) {
                    .integer => |v| @intCast(v),
                    .float => |v| @intFromFloat(v),
                    else => return error.InvalidTileData,
                };
            }
            break :blk result;
        },
        else => error.InvalidTileData,
    };
}
