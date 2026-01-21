const std = @import("std");
const tiled = @import("tiled.zig");

const Vector2 = struct { x: u32, y: u32 };

const Map = struct {
    height: u32,
    width: u32,

    tileSize: Vector2,
    layers: []Layer,
    tileSets: []TileSet,
};

const LayerEnum = enum { image, tile, object };

const Layer = struct {
    id: u32,
    image: u32,
    type: LayerEnum,

    width: u32 = 0,
    height: u32 = 0,

    offset: struct { x: i32, y: i32 },

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

pub const TileSet = struct {
    columns: u32,
    min: u32,
    max: u32,
    images: []u32,
};

// pub const TileSet = tiled.TileSet;

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
    var content = try std.fs.cwd().readFileAlloc(a, name, max);

    const parseJson = std.json.parseFromSliceLeaky;
    const tiledMap = try parseJson(tiled.TiledMap, a, content, .{ .ignore_unknown_fields = true });

    const layers: []Layer = try a.alloc(Layer, tiledMap.layers.len);

    var layerCount: usize = 0;
    for (layers, tiledMap.layers) |*layer, old| {
        var layerEnum: LayerEnum = .tile;
        var width: u32, var height: u32 = .{ 0, 0 };
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
            .image = image,
            .type = layerEnum,
            .width = width,
            .height = height,
            .offset = .{ .x = old.offsetx, .y = old.offsety },
            .data = old.data orelse &.{},
            .objects = objects,
            .parallaxX = old.parallaxx orelse 1.0,
            .parallaxY = old.parallaxy orelse 1.0,
            .repeatX = old.repeatx orelse false,
            .repeatY = old.repeaty orelse false,
        };

        if (old.visible) layerCount += 1;
    }

    // 获取 tmx 文件所在的目录
    const nameDir = std.fs.path.dirname(name) orelse ".";
    var dir = try std.fs.cwd().openDir(nameDir, .{});
    defer dir.close();

    const tileSets: []TileSet = try a.alloc(TileSet, tiledMap.tilesets.len);
    for (tileSets, tiledMap.tilesets, 0..) |*ts, old, index| {

        // 读取 tileSet 文件
        content = try dir.readFileAlloc(a, old.source, max);
        std.log.info("read tileSet: {s}", .{old.source});
        const tileSet = try parseJson(tiled.TileSet, a, content, .{});

        if (tileSet.columns > 0) {
            std.log.info("Loaded tileSet: {s} ({}x{} tiles)", .{ tileSet.name, tileSet.columns, tileSet.tilecount / tileSet.columns });
        } else {
            std.log.info("Loaded tileSet: {s} ({} tiles - collection)", .{ tileSet.name, tileSet.tilecount });
        }

        const min = tiledMap.tilesets[index].firstgid;
        var maxId: u32 = 0;
        if (index == tileSets.len - 1) {
            maxId = min + tileSet.tilecount;
        } else {
            maxId = tiledMap.tilesets[index + 1].firstgid;
        }

        var images: []u32 = &.{};
        if (tileSet.image.len != 0) {
            images = try a.alloc(u32, 1);
            images[0] = std.hash.Fnv1a_32.hash(tileSet.image[3..]);
        } else {
            images = try a.alloc(u32, maxId - min);
            @memset(images, 0);
            for (tileSet.tiles) |tile| {
                images[tile.id] = std.hash.Fnv1a_32.hash(tile.image[3..]);
            }
        }

        ts.* = TileSet{
            .columns = tileSet.columns,
            .min = tiledMap.tilesets[index].firstgid,
            .max = maxId,
            .images = images,
        };
    }

    const map: Map = .{
        .height = tiledMap.height,
        .width = tiledMap.width,
        .layers = layers[0..layerCount],
        .tileSize = .{ .x = tiledMap.tilewidth, .y = tiledMap.tileheight },
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
