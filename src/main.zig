const std = @import("std");

const window = @import("window.zig");
const audio = @import("audio.zig");
const scene = @import("scene.zig");

var soundBuffer: [20]audio.Sound = undefined;

fn init() void {
    audio.init(44100 / 4, &soundBuffer);
    scene.init();
}

fn update(delta: f32) void {
    scene.update(delta);
}

fn render() void {
    scene.render();
}

fn deinit() void {
    audio.deinit();
}

pub fn main() void {
    var allocator: std.mem.Allocator = undefined;
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

    window.run(.{
        .alloc = allocator,
        .title = "教你制作RPG游戏",
        .size = .{ .x = 800, .y = 600 },
        .init = init,
        .update = update,
        .render = render,
        .deinit = deinit,
    });
}
