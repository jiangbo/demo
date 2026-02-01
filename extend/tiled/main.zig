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
    tileSetRefs: []const TileSet,
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
    gid: u32,
    position: Vector2,
    size: Vector2,
    properties: []const parsed.Property,
    extend: ObjectExtend, // 扩展信息
};
const TileSet = struct { id: u32, firstGid: u32, max: u32 };

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

    const tileSets = try allocator.alloc(TileSet, tiledMap.tilesets.len);
    for (tileSets, tiledMap.tilesets, 0..) |*tileSet, old, index| {
        var maxGid: u32 = std.math.maxInt(u32);
        if (index < tileSets.len - 1) {
            maxGid = tiledMap.tilesets[index + 1].firstgid;
        }

        var tileSetName = old.source.?;
        if (std.mem.startsWith(u8, tileSetName, "tileset/")) {
            tileSetName = tileSetName[8..];
        }
        const id = std.hash.Fnv1a_32.hash(tileSetName);

        std.log.info("{s} ----> {}", .{ tileSetName, id });
        tileSet.* = TileSet{
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
        .layers = try parseLayers(tiledMap.layers),
        .tileSize = .{
            .x = @floatFromInt(tiledMap.tilewidth),
            .y = @floatFromInt(tiledMap.tileheight),
        },
        .tileSetRefs = tileSets,
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

fn parseLayers(layers: []tiled.Layer) ![]Layer {
    const result: []Layer = try allocator.alloc(Layer, layers.len);

    var layerCount: usize = 0;
    for (result, layers) |*layer, old| {
        var layerEnum: LayerEnum = .tile;
        var width: i32, var height: i32 = .{ 0, 0 };
        var objects: []Object = &.{};
        var image: u32 = 0;
        if (std.mem.eql(u8, "imagelayer", old.type)) {
            layerEnum = .image;
            width = old.imagewidth orelse 0;
            height = old.imageheight orelse 0;
            image = std.hash.Fnv1a_32.hash(old.image.?[3..]);
        } else if (std.mem.eql(u8, "tilelayer", old.type)) {
            layerEnum = .tile;
            width = old.width orelse 0;
            height = old.height orelse 0;
        } else if (std.mem.eql(u8, "objectgroup", old.type)) {
            layerEnum = .object;
            objects = try allocator.alloc(Object, old.objects.len);
            for (objects, old.objects) |*new, obj| {
                const gid = obj.gid orelse 0;
                new.* = Object{
                    .gid = gid & 0x1FFFFFFF,
                    .position = .{ .x = obj.x, .y = obj.y },
                    .size = .{ .x = obj.width, .y = obj.height },
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
            .data = old.data,
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
        .object => .{ .object = @intCast(property.value.integer) },
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
