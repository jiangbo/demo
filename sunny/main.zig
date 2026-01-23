const std = @import("std");
const builtin = @import("builtin");
const zhu = @import("zhu");

const scene = @import("scene.zig");

var vertexBuffer: []zhu.batch.Vertex = undefined;
var soundBuffer: [20]zhu.audio.Sound = undefined;

const atlas: zhu.Atlas = @import("zon/atlas.zon");

pub fn init() void {
    zhu.audio.init(44100 / 2, &soundBuffer);
    // window.initText(@import("zon/font.zon"), 32);

    vertexBuffer = zhu.window.alloc(zhu.batch.Vertex, 5000);
    zhu.graphics.frameStats(true);
    zhu.assets.loadAtlas(atlas);
    zhu.batch.init(zhu.window.size, vertexBuffer);
    zhu.batch.whiteImage = zhu.getImage("white.png");
    scene.init();
}

pub fn frame(delta: f32) void {
    scene.update(delta);
    scene.draw();
}

pub fn deinit() void {
    scene.deinit();
    zhu.window.free(vertexBuffer);
    zhu.audio.deinit();
}

pub fn main() void {
    var allocator: std.mem.Allocator = undefined;
    var debugAllocator: std.heap.DebugAllocator(.{}) = undefined;
    if (builtin.mode == .Debug) {
        debugAllocator = std.heap.DebugAllocator(.{}).init;
        allocator = debugAllocator.allocator();
    } else {
        allocator = std.heap.c_allocator;
    }

    defer if (builtin.mode == .Debug) {
        _ = debugAllocator.deinit();
    };

    zhu.window.run(allocator, .{
        .title = "阳光岛",
        .size = .xy(640, 360),
        .scaleEnum = .integer,
    });
}
