const std = @import("std");

const cache = @import("cache.zig");
const window = @import("window.zig");
const math = @import("math.zig");
const gfx = @import("graphics.zig");
const audio = @import("audio.zig");
const scene = @import("scene.zig");

var soundBuffer: [10]audio.Sound = undefined;

fn init() callconv(.C) void {
    cache.init(allocator);
    gfx.init(window.width, window.height);
    audio.init(&soundBuffer);

    scene.init();
}

fn event(ev: ?*const window.Event) callconv(.C) void {
    if (ev) |e| scene.event(e);
}

fn frame() callconv(.C) void {
    scene.update();
    scene.render();
}

fn deinit() callconv(.C) void {
    scene.deinit();
    audio.deinit();
    gfx.deinit();
    cache.deinit();
}

var allocator: std.mem.Allocator = undefined;

// pub fn main() void {
//     var debugAllocator = std.heap.DebugAllocator(.{}).init;
//     defer _ = debugAllocator.deinit();

//     allocator = debugAllocator.allocator();
//     window.width = 1280;
//     window.height = 720;

//     var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
//     math.rand = prng.random();
//     window.rand = prng.random();

//     window.run(.{
//         .window_title = "空洞武士",
//         .width = @as(i32, @intFromFloat(window.width)),
//         .height = @as(i32, @intFromFloat(window.height)),
//         .init_cb = init,
//         .event_cb = event,
//         .frame_cb = frame,
//         .cleanup_cb = deinit,
//     });
// }

pub fn main() !void {
    var debugAllocator = std.heap.DebugAllocator(.{}).init;
    defer _ = debugAllocator.deinit();

    allocator = debugAllocator.allocator();

    const http = @import("http.zig");
    http.init(allocator);
    defer http.deinit();

    const playerId = http.sendValue("http://127.0.0.1:4444/api/login", null);
    std.log.info("player id: {d}", .{playerId});
    std.time.sleep(5 * std.time.ns_per_s);

    const p2 = http.sendValue("http://127.0.0.1:4444/api/update1", 4);
    std.log.info("player2 progress: {d}", .{p2});
    std.time.sleep(5 * std.time.ns_per_s);

    const text = http.sendAlloc(allocator, "http://127.0.0.1:4444/api/text");
    defer text.deinit();

    std.log.info("text: {s}", .{text.items});
    std.time.sleep(5 * std.time.ns_per_s);

    const exitId = http.sendValue("http://127.0.0.1:4444/api/logout", playerId);
    std.log.info("exit id: {d}", .{exitId});
}
