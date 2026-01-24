const std = @import("std");
const tiled = @import("tiled.zig");

const Vector2 = struct { x: i32, y: i32 };

const Map = struct {
    height: i32,
    width: i32,

    tileSize: Vector2,
    layers: []Layer,
    states: []u32,
    tileSets: []TileSet,
};

const LayerEnum = enum { image, tile, object };

const Layer = struct {
    id: u32,
    image: u32,
    type: LayerEnum,

    width: u32 = 0,
    height: u32 = 0,

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

pub const TileSet = struct {
    columns: u32,
    min: u32,
    max: u32,
    images: []u32,
};

pub const OriginTileSet = struct {
    columns: u32,
    min: u32,
    max: u32,
    images: []u32,
    states: []u32,

    fn toOutputTileSet(self: OriginTileSet) TileSet {
        return TileSet{
            .columns = self.columns,
            .min = self.min,
            .max = self.max,
            .images = self.images,
        };
    }
};

const parseJson = std.json.parseFromSliceLeaky;
const Allocator = std.mem.Allocator;
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
    const tiledMap = try parseJson(tiled.TiledMap, a, content, .{});

    const tileSets = try parseTileSet(a, tiledMap, name);
    const outputTileSets = try a.alloc(TileSet, tileSets.len);
    for (tileSets, 0..) |ts, i| {
        outputTileSets[i] = ts.toOutputTileSet();
    }
    const layers = try parseLayers(a, tiledMap);

    // 检测碰撞属性
    const len: usize = @intCast(tiledMap.width * tiledMap.height);
    const outputStates = try a.alloc(u32, len);
    for (layers[3].data, outputStates) |tile, *state| {
        if (states[tile] != 0) {
            std.log.info("state: {}", .{states[tile]});
        }
        state.* = states[tile];
    }

    const map: Map = .{
        .height = tiledMap.height,
        .width = tiledMap.width,
        .layers = layers,
        .tileSize = .{ .x = tiledMap.tilewidth, .y = tiledMap.tileheight },
        .tileSets = outputTileSets,
        .states = outputStates,
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

var states: []u32 = &.{};
fn parseTileSet(a: Allocator, tileMap: tiled.TiledMap, name: []const u8) ![]OriginTileSet {
    // 获取 tmx 文件所在的目录
    const nameDir = std.fs.path.dirname(name) orelse ".";
    var dir = try std.fs.cwd().openDir(nameDir, .{});
    defer dir.close();

    const last = tileMap.tilesets[tileMap.tilesets.len - 1];
    states = try a.alloc(u32, last.firstgid + 1024);
    @memset(states, 0);

    const max = std.math.maxInt(u32);
    const tileSets = try a.alloc(OriginTileSet, tileMap.tilesets.len);
    for (tileSets, tileMap.tilesets, 0..) |*ts, old, index| {

        // 读取 tileSet 文件
        const content = try dir.readFileAlloc(a, old.source, max);
        std.log.info("read tileSet: {s}", .{old.source});
        const tileSet = try parseJson(tiled.TileSet, a, content, .{});

        if (tileSet.columns > 0) {
            std.log.info("Loaded tileSet: {s} ({}x{} tiles)", .{ tileSet.name, tileSet.columns, tileSet.tilecount / tileSet.columns });
        } else {
            std.log.info("Loaded tileSet: {s} ({} tiles - collection)", .{ tileSet.name, tileSet.tilecount });
        }

        const min = tileMap.tilesets[index].firstgid;
        var maxId: u32 = 0;
        if (index == tileSets.len - 1) {
            maxId = min + tileSet.tilecount;
        } else {
            maxId = tileMap.tilesets[index + 1].firstgid;
        }

        for (tileSet.tiles) |tile| {
            if (tile.properties.len == 0) continue;

            const property = tile.properties[0];
            if (!std.mem.eql(u8, property.name, "solid")) continue;

            if (property.value.bool) {
                const id = tile.id + min;
                std.log.info("id: {}", .{id});
                states[id] = 1;
            }
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

        ts.* = OriginTileSet{
            .columns = tileSet.columns,
            .min = tileMap.tilesets[index].firstgid,
            .max = maxId,
            .images = images,
            .states = states,
        };
    }
    return tileSets;
}

fn parseLayers(a: Allocator, tiledMap: tiled.TiledMap) ![]Layer {
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
                    .gid = obj.gid.?,
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

    return layers[0..layerCount];
}
