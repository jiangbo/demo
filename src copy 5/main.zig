const std = @import("std");

const cache = @import("cache.zig");
const window = @import("window.zig");
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

pub fn main() void {
    var debugAllocator = std.heap.DebugAllocator(.{}).init;
    defer _ = debugAllocator.deinit();

    allocator = debugAllocator.allocator();
    window.width = 1280;
    window.height = 720;

    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    window.rand = prng.random();

    window.run(.{
        .window_title = "空洞武士",
        .width = @as(i32, @intFromFloat(window.width)),
        .height = @as(i32, @intFromFloat(window.height)),
        .init_cb = init,
        .event_cb = event,
        .frame_cb = frame,
        .cleanup_cb = deinit,
    });
}
