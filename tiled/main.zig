const std = @import("std");
const tiled = @import("tiled.zig");

const Map = struct {
    height: u32,
    width: u32,

    tileWidth: u32,
    tileHeight: u32,
    layers: []Layer,
    tileSets: []TileSetRef,
};

const LayerEnum = enum { image, tile, object };

const Layer = struct {
    id: u32,
    name: []const u8,
    type: LayerEnum,

    width: u32 = 0,
    height: u32 = 0,
    opacity: f32,
    visible: bool,

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
    id: u32,
    name: []const u8,
    type: []const u8,

    gid: u32,

    x: f32,
    y: f32,

    width: f32,
    height: f32,

    rotation: f32,
    visible: bool,
};

pub const TileSetRef = struct { firstGid: u32, source: []const u8 };

pub fn main() !void {
    var debugAllocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debugAllocator.deinit();
    var arena = std.heap.ArenaAllocator.init(debugAllocator.allocator());
    defer arena.deinit();
    const a = arena.allocator();

    const args = try std.process.argsAlloc(a);
    if (args.len != 2) return error.invalidArgs;
    const name = args[1];
    std.log.info("file name: {s}", .{name});

    const max = std.math.maxInt(usize);
    const content = try std.fs.cwd().readFileAlloc(a, name, max);

    const j = std.json;
    const tiledMap = try j.parseFromSliceLeaky(tiled.TiledMap, a, content, .{});

    const layers: []Layer = try a.alloc(Layer, tiledMap.layers.len);

    for (layers, tiledMap.layers) |*layer, old| {
        var layerEnum: LayerEnum = .tile;
        var width: u32, var height: u32 = .{ 0, 0 };
        var objects: []Object = &.{};
        if (std.mem.eql(u8, "imagelayer", old.type)) {
            layerEnum = .image;
            width = old.imagewidth orelse 0;
            height = old.imageheight orelse 0;
        } else if (std.mem.eql(u8, "tilelayer", old.type)) {
            layerEnum = .tile;
            width = old.width orelse 0;
            height = old.height orelse 0;
        } else if (std.mem.eql(u8, "objectgroup", old.type)) {
            layerEnum = .object;
            objects = try a.alloc(Object, old.objects.?.len);
            for (objects, old.objects.?) |*object, obj| {
                object.* = Object{
                    .id = obj.id,
                    .name = obj.name,
                    .type = obj.type,
                    .gid = obj.gid.?,
                    .x = obj.x,
                    .y = obj.y,
                    .width = obj.width,
                    .height = obj.height,
                    .rotation = obj.rotation,
                    .visible = obj.visible,
                };
            }
        } else return error.invalidLayerType;

        layer.* = Layer{
            .id = old.id,
            .name = old.name,
            .type = layerEnum,
            .width = width,
            .height = height,
            .opacity = old.opacity,
            .visible = old.visible,
            .data = old.data orelse &.{},
            .objects = objects,
            .parallaxX = old.parallaxx orelse 1.0,
            .parallaxY = old.parallaxy orelse 1.0,
            .repeatX = old.repeatx orelse false,
            .repeatY = old.repeaty orelse false,
        };
    }

    const tileSets: []TileSetRef = try a.alloc(TileSetRef, tiledMap.tilesets.len);
    for (tileSets, tiledMap.tilesets) |*ts, old| {
        ts.* = TileSetRef{
            .firstGid = old.firstgid,
            .source = old.source,
        };
    }

    const map: Map = .{
        .height = tiledMap.height,
        .width = tiledMap.width,
        .layers = layers,
        .tileWidth = tiledMap.tilewidth,
        .tileHeight = tiledMap.tileheight,
        .tileSets = tileSets,
    };

    // 写入 font.zon 文件
    const outputName = try std.mem.replaceOwned(u8, a, name, ".tmj", ".zon");
    const file = try std.fs.cwd().createFile(outputName, .{});
    defer file.close();
    var buffer: [4096]u8 = undefined;
    var writer = file.writer(&buffer);
    try std.zon.stringify.serialize(map, .{}, &writer.interface);
    try writer.interface.flush();
}
