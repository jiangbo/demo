const std = @import("std");
const builtin = @import("builtin");
const zhu = @import("zhu");

const tiled = zhu.extend.tiled;
const gui = @import("gui.zig");
const scene = @import("scene.zig");
const hud = @import("hud.zig");
const ctx = @import("context.zig");

var vertexBuffer: []zhu.batch.Vertex = undefined;
var commandBuffer: [64]zhu.batch.Command = undefined;
var soundBuffer: [20]zhu.audio.Sound = undefined;
const tileSets: []const tiled.TileSet = @import("zon/tile.zon");
const atlas: zhu.Atlas = @import("zon/atlas.zon");
const fontZon: zhu.text.BitMapFont = @import("zon/font.zon");

pub fn init() void {
    zhu.audio.init(44100 / 2, &soundBuffer);

    vertexBuffer = zhu.assets.oomAlloc(zhu.batch.Vertex, 8000);
    zhu.graphics.frameStats(true);
    zhu.assets.loadAtlas(atlas);
    zhu.batch.init(vertexBuffer, &commandBuffer);
    const whiteCircle = zhu.getImage("circle.png");
    const area: zhu.Rect = .init(.xy(16, 16), .xy(32, 32));
    zhu.batch.whiteImage = whiteCircle.sub(area);

    tiled.init(tileSets);

    const fontImage = zhu.assets.loadImage("assets/font.png", .zero);
    zhu.text.initBitMapFont(fontImage, fontZon, 32);

    gui.init();
    ctx.init();
    hud.init();
    scene.init();
}

pub fn event(ev: *const zhu.window.Event) void {
    gui.event(ev);
}

pub fn frame(delta: f32) void {
    gui.update(delta);
    ctx.update(delta);
    hud.update();
    scene.update(delta);

    zhu.batch.beginDraw(tiled.backgroundColor orelse .black);
    scene.draw();
    hud.draw();
    zhu.batch.flush();
    gui.draw();
    zhu.batch.commit();
}

pub fn deinit() void {
    scene.deinit();
    hud.deinit();
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
        .size = .xy(800, 608),
        .logicSize = .xy(1600, 1216),
        .scaleEnum = .integer,
        .maxFileSize = 5 * 1024 * 1024,
    });
}
