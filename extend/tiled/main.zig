const std = @import("std");
const tiled = @import("tiled.zig");
const parsed = @import("parsed.zig");

const parseJson = std.json.parseFromSliceLeaky;
const Vector2 = struct { x: f32, y: f32 };

var allocator: std.mem.Allocator = undefined;

const TiledMap = struct {
    height: i32,
    width: i32,
    backgroundColor: ?Color = null,

    tileSize: Vector2,
    layers: []Layer,
    tileSetRefs: []const TileSetRef,
};

const LayerEnum = enum { image, tile, object };
const Layer = struct {
    id: u32,
    name: []const u8,
    image: u32,
    type: LayerEnum,
    width: f32,
    height: f32,

    offset: Vector2,

    // tile 层特有
    data: []const u32,

    // 对象层特有
    objects: []Object,

    // 图片层
    parallaxX: f32 = 1.0,
    parallaxY: f32 = 1.0,

    repeatX: bool = false,
    repeatY: bool = false,
};

const ObjectExtend = packed struct(u8) {
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
    position: Vector2,
    size: Vector2,
    point: bool,
    properties: []const parsed.Property,
    extend: ObjectExtend, // 扩展信息
};

const TileSetRef = struct { id: u32 };
const TileSetRange = struct { id: u32, firstGid: u32, max: u32 };

pub fn main() !void {
    var debugAllocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debugAllocator.deinit();
    var arena = std.heap.ArenaAllocator.init(debugAllocator.allocator());
    defer arena.deinit();
    allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    if (args.len != 2) return error.invalidArgs;
    const name = args[1];
    std.log.info("file name: {s}", .{name});

    const max = std.math.maxInt(usize);
    const content = try std.fs.cwd().readFileAlloc(allocator, name, max);
    const tiledMap = try parseJson(tiled.Map, allocator, content, .{});

    const tileSetRanges = try allocator.alloc(TileSetRange, tiledMap.tilesets.len);
    const tileSetRefs = try allocator.alloc(TileSetRef, tiledMap.tilesets.len);
    for (tileSetRanges, tileSetRefs, tiledMap.tilesets, 0..) |*range, *ref, old, index| {
        var maxGid: u32 = std.math.maxInt(u32);
        if (index < tileSetRanges.len - 1) {
            maxGid = tiledMap.tilesets[index + 1].firstgid;
        }

        var tileSetName = old.source.?;
        if (std.mem.startsWith(u8, tileSetName, "tileset/")) {
            tileSetName = tileSetName[8..];
        }
        const id = std.hash.Fnv1a_32.hash(tileSetName);

        std.log.info("{s} ----> {}", .{ tileSetName, id });
        ref.* = .{ .id = id };
        range.* = TileSetRange{
            .id = id,
            .firstGid = old.firstgid,
            .max = maxGid,
        };
    }
    var color: ?Color = null;
    if (tiledMap.backgroundcolor) |c| color = parseColor(c);

    const map = TiledMap{
        .height = tiledMap.height,
        .width = tiledMap.width,
        .layers = try parseLayers(tiledMap.layers, tileSetRanges),
        .tileSize = .{
            .x = @floatFromInt(tiledMap.tilewidth),
            .y = @floatFromInt(tiledMap.tileheight),
        },
        .tileSetRefs = tileSetRefs,
        .backgroundColor = color,
    };

    // 写入 font.zon 文件
    const replace = std.mem.replaceOwned;
    const outputName = try replace(u8, allocator, name, ".tmj", ".zon");
    const file = try std.fs.cwd().createFile(outputName, .{});
    defer file.close();
    var buffer: [4096]u8 = undefined;
    var writer = file.writer(&buffer);
    try std.zon.stringify.serialize(map, .{}, &writer.interface);
    try writer.interface.flush();
}

const TileSetMatch = struct { index: u8, localId: u32 };

fn findTileSet(gid: u32, tileSetRanges: []const TileSetRange) ?TileSetMatch {
    if (gid == 0) return null;
    const cleanGid = gid & 0x1FFFFFFF;
    if (cleanGid == 0) return null;

    for (tileSetRanges, 0..) |ts, i| {
        if (cleanGid >= ts.firstGid and cleanGid < ts.max) {
            return .{
                .index = @intCast(i),
                .localId = cleanGid - ts.firstGid,
            };
        }
    }
    return null;
}

fn encodeGid(gid: u32, tileSetRanges: []const TileSetRange) u32 {
    if (gid == 0) return 0;
    if (findTileSet(gid, tileSetRanges)) |res| {
        std.debug.assert(res.localId <= 0x00FFFFFF);
        const tileSetTag = @as(u32, res.index) + 1;
        return (tileSetTag << 24) | res.localId;
    }
    std.debug.panic("tiled compiler: GID {} has no matching tileSet", .{gid});
}

fn parseLayers(layers: []tiled.Layer, tileSetRanges: []const TileSetRange) ![]Layer {
    const result: []Layer = try allocator.alloc(Layer, layers.len);

    var layerCount: usize = 0;
    for (result, layers) |*layer, old| {
        var layerEnum: LayerEnum = .tile;
        var width: i32, var height: i32 = .{ 0, 0 };
        var objects: []Object = &.{};
        var image: u32 = 0;
        var layerData: []const u32 = &.{};

        if (std.mem.eql(u8, "imagelayer", old.type)) {
            layerEnum = .image;
            width = old.imagewidth orelse 0;
            height = old.imageheight orelse 0;
            image = std.hash.Fnv1a_32.hash(old.image.?[3..]);
        } else if (std.mem.eql(u8, "tilelayer", old.type)) {
            layerEnum = .tile;
            width = old.width orelse 0;
            height = old.height orelse 0;

            // 编码 Tile Layer 的 GID，高 8 位为 TileSet 序号，低 24 位为 localId
            const encoded = try allocator.alloc(u32, old.data.len);
            for (old.data, 0..) |rawGid, idx| {
                encoded[idx] = encodeGid(rawGid, tileSetRanges);
            }
            layerData = encoded;
        } else if (std.mem.eql(u8, "objectgroup", old.type)) {
            layerEnum = .object;
            objects = try allocator.alloc(Object, old.objects.len);
            for (objects, old.objects) |*new, obj| {
                const gid = obj.gid orelse 0;
                new.* = Object{
                    .id = obj.id,
                    .gid = encodeGid(gid, tileSetRanges),
                    .name = obj.name,
                    .type = obj.type,
                    .position = .{ .x = obj.x, .y = obj.y },
                    .size = .{ .x = obj.width, .y = obj.height },
                    .point = obj.point,
                    .properties = try parseProperties(obj.properties),
                    .extend = .{
                        .flipX = (gid & 0x80000000) != 0,
                        .flipY = (gid & 0x40000000) != 0,
                        .rotation = (gid & 0x20000000) != 0,
                    },
                };
            }
        } else return error.invalidLayerType;

        layer.* = Layer{
            .id = old.id,
            .name = old.name,
            .image = image,
            .type = layerEnum,
            .width = @floatFromInt(width),
            .height = @floatFromInt(height),
            .offset = .{ .x = old.offsetx, .y = old.offsety },
            .data = layerData,
            .objects = objects,
            .parallaxX = old.parallaxx,
            .parallaxY = old.parallaxy,
            .repeatX = old.repeatx orelse false,
            .repeatY = old.repeaty orelse false,
        };

        if (old.visible) layerCount += 1;
    }

    return result[0..layerCount];
}

fn parseProperties(properties: []tiled.Property) ![]parsed.Property {
    const result = try allocator.alloc(parsed.Property, properties.len);
    for (properties, 0..) |property, i| {
        result[i] = .{
            .name = property.name,
            .value = try parsePropertyValue(property),
        };
    }
    return result;
}

const toEnum = std.meta.stringToEnum;
fn parsePropertyValue(property: tiled.Property) !parsed.PropertyValue {
    return switch (toEnum(parsed.PropertyEnum, property.type).?) {
        .string => .{ .string = property.value.string },
        .int => .{ .int = @intCast(property.value.integer) },
        .float => switch (property.value) {
            .float => |f| .{ .float = @floatCast(f) },
            .integer => |i| .{ .float = @floatFromInt(i) },
            else => @panic("Expected a number type for .float"),
        },
        .bool => .{ .bool = property.value.bool },
        .class => .{ .class = try parseClassProperty(property) },
        .object => .{ .object = @intCast(property.value.integer) },
    };
}

fn parseClassProperty(property: tiled.Property) !parsed.ClassProperty {
    return .{
        .type = property.propertytype orelse return error.MissingClassType,
        .properties = try parseClassProperties(property.value),
    };
}

fn parseClassProperties(value: std.json.Value) ![]const parsed.ClassMember {
    var object = switch (value) {
        .object => |object| object,
        else => return error.InvalidClassProperty,
    };

    const result = try allocator.alloc(parsed.ClassMember, object.count());
    var it = object.iterator();
    var index: usize = 0;
    while (it.next()) |entry| : (index += 1) {
        result[index] = .{
            .name = entry.key_ptr.*,
            .value = try parseClassMemberValue(entry.value_ptr.*),
        };
    }
    return result;
}

fn parseClassMemberValue(value: std.json.Value) !parsed.ClassMemberValue {
    return switch (value) {
        .string => |v| .{ .string = v },
        .integer => |v| .{ .float = @floatFromInt(v) },
        .float => |v| .{ .float = @floatCast(v) },
        .bool => |v| .{ .bool = v },
        else => error.InvalidClassMemberValue,
    };
}

pub const Color = struct { r: f32, g: f32, b: f32, a: f32 };

pub fn parseColor(hexStr: []const u8) Color {
    const hex = if (hexStr[0] == '#') hexStr[1..] else hexStr;

    // 验证长度（必须是 6 或 8）
    std.debug.assert(hex.len == 6 or hex.len == 8);

    // 将十六进制字符串解析为 u32
    const value = std.fmt.parseInt(u32, hex, 16) catch unreachable;
    const alpha: u32 = if (hex.len == 6) 255 else value & 0xFF;
    const rbg = if (hex.len == 6) value else value >> 8;
    return Color{
        .r = @as(f32, @floatFromInt((rbg >> 16) & 0xFF)) / 255.0,
        .g = @as(f32, @floatFromInt((rbg >> 8) & 0xFF)) / 255.0,
        .b = @as(f32, @floatFromInt(rbg & 0xFF)) / 255.0,
        .a = @as(f32, @floatFromInt(alpha)) / 255.0,
    };
}
