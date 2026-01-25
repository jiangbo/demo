const std = @import("std");
const tiled = @import("tiled.zig");

const parseJson = std.json.parseFromSliceLeaky;
const Vector2 = struct { x: f32, y: f32 };

var allocator: std.mem.Allocator = undefined;

const TiledMap = struct {
    height: i32,
    width: i32,

    tileSize: Vector2,
    layers: []Layer,
    tileSetRefs: []const TileSet,
};

const LayerEnum = enum { image, tile, object };
const Layer = struct {
    id: u32,
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

pub const Object = struct {
    gid: u32,
    position: Vector2,
    size: Vector2,
    rotation: f32,
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

        tileSet.* = TileSet{
            .id = std.hash.Fnv1a_32.hash(old.source.?),
            .firstGid = old.firstgid,
            .max = maxGid,
        };
    }

    const map = TiledMap{
        .height = tiledMap.height,
        .width = tiledMap.width,
        .layers = try parseLayers(tiledMap.layers),
        .tileSize = .{
            .x = @floatFromInt(tiledMap.tilewidth),
            .y = @floatFromInt(tiledMap.tileheight),
        },
        .tileSetRefs = tileSets,
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
            objects = try allocator.alloc(Object, old.objects.?.len);
            for (objects, old.objects.?) |*object, obj| {
                object.* = Object{
                    .gid = obj.gid orelse 0,
                    .position = .{ .x = obj.x, .y = obj.y },
                    .size = .{ .x = obj.width, .y = obj.height },
                    .rotation = obj.rotation,
                };
            }
        } else return error.invalidLayerType;

        layer.* = Layer{
            .id = old.id,
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
