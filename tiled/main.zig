const std = @import("std");
const tiled = @import("tiled.zig");

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
    const tiledMap = try parseJson(tiled.Map, a, content, .{});

    std.log.info("tiled map: {any}", .{tiledMap});
}

// fn parseTileSet(a: Allocator, tileMap: tiled.Map, name: []const u8) ![]OriginTileSet {

//     // 获取 tmx 文件所在的目录
//     const nameDir = std.fs.path.dirname(name) orelse ".";
//     var dir = try std.fs.cwd().openDir(nameDir, .{});
//     defer dir.close();

//     const last = tileMap.tilesets[tileMap.tilesets.len - 1];
//     states = try a.alloc(u32, last.firstgid + 1024);
//     @memset(states, 0);

//     const max = std.math.maxInt(u32);
//     const tileSets = try a.alloc(OriginTileSet, tileMap.tilesets.len);
//     for (tileSets, tileMap.tilesets, 0..) |*ts, old, index| {

//         // 读取 tileSet 文件
//         const content = try dir.readFileAlloc(a, old.source, max);
//         std.log.info("read tileSet: {s}", .{old.source});
//         const tileSet = try parseJson(tiled.TileSet, a, content, .{});

//         if (tileSet.columns > 0) {
//             std.log.info("Loaded tileSet: {s} ({}x{} tiles)", .{ tileSet.name, tileSet.columns, tileSet.tilecount / tileSet.columns });
//         } else {
//             std.log.info("Loaded tileSet: {s} ({} tiles - collection)", .{ tileSet.name, tileSet.tilecount });
//         }

//         const min = tileMap.tilesets[index].firstgid;
//         var maxId: u32 = 0;
//         if (index == tileSets.len - 1) {
//             maxId = min + tileSet.tilecount;
//         } else {
//             maxId = tileMap.tilesets[index + 1].firstgid;
//         }

//         for (tileSet.tiles) |tile| {
//             if (tile.properties.len == 0) continue;

//             const property = tile.properties[0];
//             if (!std.mem.eql(u8, property.name, "solid")) continue;

//             if (property.value.bool) {
//                 const id = tile.id + min;
//                 states[id] = 1;
//             }
//         }

//         var images: []u32 = &.{};
//         if (tileSet.image.len != 0) {
//             images = try a.alloc(u32, 1);
//             images[0] = std.hash.Fnv1a_32.hash(tileSet.image[3..]);
//             std.log.info("image: {s}, id: {}", .{ tileSet.image[3..], images[0] });
//         } else {
//             images = try a.alloc(u32, maxId - min);
//             @memset(images, 0);
//             for (tileSet.tiles) |tile| {
//                 images[tile.id] = std.hash.Fnv1a_32.hash(tile.image[3..]);
//                 std.log.info("image: {s}, id: {}", .{ tile.image[3..], images[tile.id] });
//             }
//         }

//         ts.* = OriginTileSet{
//             .columns = tileSet.columns,
//             .min = tileMap.tilesets[index].firstgid,
//             .max = maxId,
//             .images = images,
//             .states = states,
//         };
//     }
//     return tileSets;
// }
