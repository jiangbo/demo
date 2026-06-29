const std = @import("std");
const assets = @import("../assets.zig");
const tiled = @import("tiled.zig");
const map_file = @import("map_file.zig");

// 地图运行时加载器：搭 assets 异步文件管线，解码 .bin 为 tiled.Map 并缓存。
// 地图切换从「编译期常量」变为「异步就绪」，调用方用 getMap 每帧轮询。

var mapCache: std.AutoHashMapUnmanaged(assets.Id, tiled.Map) = .empty;

/// 请求异步加载一张地图二进制；就绪后自动存入缓存。
pub fn loadMap(path: [:0]const u8) void {
    _ = assets.file.load(path, assets.id(path), mapHandler);
}

/// 预留缓存容量，避免后续 put 触发 rehash 导致 getMap 返回的指针失效。
/// 调用方应在首次 loadMap 前按地图总数预留。
pub fn ensureCapacity(n: usize) void {
    mapCache.ensureTotalCapacity(assets.allocator, @intCast(n)) catch assets.oom();
}

/// 取已加载的地图；未就绪返回 null，调用方每帧轮询直到非 null。
pub fn getMap(path: []const u8) ?*const tiled.Map {
    return mapCache.getPtr(assets.id(path));
}

/// 释放全部地图缓存（程序退出时调用）。
pub fn deinitMaps() void {
    var it = mapCache.valueIterator();
    while (it.next()) |m| map_file.deinit(assets.allocator, m.*);
    mapCache.deinit(assets.allocator);
}

// assets.file 的回调：解码字节为 Map 并入缓存。不保留原始字节（解码自有内存）。
fn mapHandler(response: assets.Response) []const u8 {
    const map = map_file.decode(assets.allocator, response.data.items) catch |err| {
        std.debug.panic("map decode failed {s}: {}", .{ response.path, err });
    };
    mapCache.put(assets.allocator, assets.id(response.path), map) catch
        assets.oom();
    return &.{};
}

test "mapHandler 解码后命中缓存" {
    const alloc = std.testing.allocator;
    assets.initCaches(alloc);
    defer assets.deinit();
    defer deinitMaps();

    // 构造一张极简地图并编码成字节
    const src: tiled.Map = .{
        .width = 2,
        .height = 1,
        .tileSize = .{ .x = 16, .y = 16 },
        .tileSetRefs = &.{},
        .layers = &.{
            .{
                .id = 1,
                .name = "g",
                .image = 0,
                .type = .tile,
                .offset = .{ .x = 0, .y = 0 },
                .data = &.{ 5, 5 },
                .objects = &.{},
            },
        },
    };
    const bytes = try map_file.encode(alloc, src);
    defer alloc.free(bytes);

    // 伪造异步响应，直接喂给 handler（借用 bytes，解码会自行复制）
    const response: assets.Response = .{
        .index = 0,
        .path = "test.bin",
        .data = .{ .items = bytes, .capacity = bytes.len },
    };
    _ = mapHandler(response);

    const got = getMap("test.bin") orelse return error.notCached;
    try std.testing.expect(got.width == 2);
    try std.testing.expectEqualSlices(u32, &.{ 5, 5 }, got.layers[0].data);
}
