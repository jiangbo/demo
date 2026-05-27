const std = @import("std");
const builtin = @import("builtin");
const zhu = @import("zhu");

const context = @import("context.zig");
const events = @import("event.zig");
const gui = @import("gui.zig");
const map = @import("map.zig");
const scene = @import("scene.zig");
const factory = @import("factory.zig");

var vertexBuffer: []zhu.batch.Vertex = undefined;
var commandBuffer: [128]zhu.batch.Command = undefined;
var soundBuffer: [20]zhu.audio.Sound = undefined;
var world: zhu.ecs.World = undefined;

pub fn init() void {
    vertexBuffer = zhu.assets.oomAlloc(zhu.batch.Vertex, 4096);
    zhu.batch.init(vertexBuffer, &commandBuffer);
    world = .init(zhu.assets.allocator);

    zhu.audio.init(44100 / 2, &soundBuffer);

    zhu.assets.loadAtlas(@import("zon/atlas.zon"));
    const whiteCircle = zhu.getImage("circle.png").?;
    const area: zhu.Rect = .init(.xy(16, 16), .xy(32, 32));
    zhu.batch.whiteImage = whiteCircle.sub(area);

    const fontImage = zhu.assets.loadImage("assets/font.png");
    zhu.text.initBitMapFont(fontImage, @import("zon/font.zon"));
    zhu.text.changeFontSize(8);

    gui.init();
    context.init();
    events.init();
    map.init();
    factory.init();
    scene.init(&world);
}

pub fn event(ev: *const zhu.window.Event) void {
    gui.event(ev);
}

pub fn frame(delta: f32) void {
    scene.update(&world, delta);
    gui.update(delta);

    zhu.batch.beginDraw(.rgb(0.23, 0.31, 0.27));
    scene.draw(&world);
    zhu.batch.flush();
    gui.draw();
    zhu.batch.commit();
    events.update();
}

pub fn deinit() void {
    scene.deinit();
    map.deinit();
    events.deinit();
    context.deinit();
    gui.deinit();
    world.deinit();
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
        .size = .xy(960, 540),
        .logicSize = .xy(320, 180),
        .scaleEnum = .integer,
        .maxFileSize = 2 * 1024 * 1024,
    });
}
