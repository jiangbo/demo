const std = @import("std");
const builtin = @import("builtin");
const zhu = @import("zhu");

const scene = @import("scene.zig");

var vertexBuffer: []zhu.batch.Vertex = undefined;
var commandBuffer: [64]zhu.batch.Command = undefined;
var soundBuffer: [20]zhu.audio.Sound = undefined;

pub fn init() void {
    vertexBuffer = zhu.assets.oomAlloc(zhu.batch.Vertex, 4096);
    zhu.batch.init(vertexBuffer, &commandBuffer);

    zhu.audio.init(44100 / 2, &soundBuffer);

    zhu.assets.loadAtlas(@import("zon/atlas.zon"));
    zhu.batch.circleImage = zhu.getImage("circle.png").?;
    const area: zhu.Rect = .init(.xy(16, 16), .xy(32, 32));
    zhu.batch.whiteImage = zhu.batch.circleImage.sub(area);

    const fontImage = zhu.assets.loadImage("assets/font.png", .zero);
    zhu.text.init(fontImage, @import("zon/font.zon"));
    zhu.text.font.lineHeight += 2;

    zhu.window.useCursor("assets/farm-rpg/UI/cursor.png", .{});

    scene.init();
}

var debug: bool = false;
pub fn frame(delta: f32) void {
    if (zhu.key.released(.X)) debug = !debug;
    scene.update(delta);

    zhu.batch.beginDraw();
    scene.draw();
    if (debug) zhu.debug.draw();
    zhu.batch.endDraw();
}

pub fn deinit() void {
    scene.deinit();
    zhu.audio.deinit();
    zhu.assets.free(vertexBuffer);
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
        .title = "迷你农场",
        .size = .xy(1280, 720),
        .logicSize = .xy(640, 360),
        .scaleEnum = .fit,
    });
}
