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

    math.setRandomSeed(timer.lap());
    scene.init();
}

export fn event(ev: ?*const window.Event) void {
    if (ev) |e| window.event(e);
}

export fn frame() void {
    const delta: f32 = @floatFromInt(timer.lap());
    cache.loading();
    scene.update(delta / std.time.ns_per_s);
    scene.render();
}

export fn deinit() void {
    audio.deinit();
    gfx.deinit();
    cache.deinit();
}

var allocator: std.mem.Allocator = undefined;
var timer: std.time.Timer = undefined;

pub fn main() void {
    var debugAllocator: std.heap.DebugAllocator(.{}) = undefined;
    if (@import("builtin").mode == .Debug) {
        debugAllocator = std.heap.DebugAllocator(.{}).init;
        allocator = debugAllocator.allocator();
    } else {
        allocator = std.heap.c_allocator;
    }

    defer if (@import("builtin").mode == .Debug) {
        _ = debugAllocator.deinit();
    };

    window.size = .{ .x = 640, .y = 480 };
    timer = std.time.Timer.start() catch unreachable;

    window.run(.{
        .window_title = "教你制作RPG游戏",
        .width = @as(i32, @intFromFloat(window.size.x)),
        .height = @as(i32, @intFromFloat(window.size.y)),
        .high_dpi = true,
        .init_cb = init,
        .event_cb = event,
        .frame_cb = frame,
        .cleanup_cb = deinit,
        .logger = .{ .func = window.log },
    });
}
