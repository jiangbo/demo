const std = @import("std");

const cache = @import("cache.zig");
const window = @import("window.zig");
const math = @import("math.zig");
const gfx = @import("graphics.zig");
const audio = @import("audio.zig");
const scene = @import("scene.zig");

var soundBuffer: [20]audio.Sound = undefined;

export fn init() void {
    cache.init(allocator);
    gfx.init(window.size);
    audio.init(&soundBuffer);

    var prng = std.Random.DefaultPrng.init(timer.lap());
    math.rand = prng.random();
    scene.init();
}

export fn event(ev: ?*const window.Event) void {
    if (ev) |e| scene.event(e);
}

export fn frame() void {
    const delta: f32 = @floatFromInt(timer.lap());
    cache.loading();
    scene.update(delta / std.time.ns_per_s);
    scene.render();
}

export fn deinit() void {
    scene.deinit();

    audio.deinit();
    gfx.deinit();
    cache.deinit();
}

var allocator: std.mem.Allocator = undefined;

var timer: std.time.Timer = undefined;

pub fn main() void {
    // var debugAllocator = std.heap.DebugAllocator(.{}).init;
    // defer _ = debugAllocator.deinit();

    // allocator = debugAllocator.allocator();

    allocator = std.heap.c_allocator;

    window.size = .{ .x = 1280, .y = 720 };
    timer = std.time.Timer.start() catch unreachable;

    window.run(.{
        .window_title = "拼好饭传奇",
        .width = @as(i32, @intFromFloat(window.size.x)),
        .height = @as(i32, @intFromFloat(window.size.y)),
        .init_cb = init,
        .event_cb = event,
        .frame_cb = frame,
        .cleanup_cb = deinit,
    });
}
