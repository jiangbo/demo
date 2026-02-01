const std = @import("std");
const builtin = @import("builtin");
const zhu = @import("zhu");

const tiled = zhu.extend.tiled;
const gui = @import("gui.zig");
const scene = @import("scene.zig");

var vertexBuffer: []zhu.batch.Vertex = undefined;
var commandBuffer: [16]zhu.batch.Command = undefined;
var soundBuffer: [20]zhu.audio.Sound = undefined;
const tileSets: []tiled.TileSet = @import("zon/tile.zon");

pub fn init() void {
    zhu.audio.init(44100 / 2, &soundBuffer);

    vertexBuffer = zhu.assets.oomAlloc(zhu.batch.Vertex, 5000);
    zhu.graphics.frameStats(true);
    zhu.batch.init(vertexBuffer, &commandBuffer);
    tiled.tileSets = tileSets;

    gui.init();
    scene.init();
}

pub fn event(ev: *const zhu.window.Event) void {
    gui.event(ev);
}

pub fn frame(delta: f32) void {
    gui.update(delta);
    scene.update(delta);

    zhu.batch.beginDraw(tiled.backgroundColor orelse .black);
    scene.draw();
    gui.draw();
    zhu.batch.endDraw();
}

pub fn deinit() void {
    scene.deinit();
    gui.deinit();
    zhu.assets.free(vertexBuffer);
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
        .title = "怪物战争",
        .size = .xy(1280, 720),
        .scaleEnum = .integer,
    });
}
