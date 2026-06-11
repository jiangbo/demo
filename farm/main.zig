const std = @import("std");
const builtin = @import("builtin");
const zhu = @import("zhu");

const context = @import("context.zig");
const map = @import("map.zig");
const scene = @import("scene.zig");
const factory = @import("factory.zig");
const ui = @import("ui.zig");

var vertexBuffer: []zhu.batch.Vertex = undefined;
var commandBuffer: [128]zhu.batch.Command = undefined;
var soundBuffer: [20]zhu.audio.Sound = undefined;
var world: zhu.ecs.World = undefined;
var canvas: zhu.graphics.RenderTarget = .{};

pub fn init() void {
    vertexBuffer = zhu.assets.oomAlloc(zhu.batch.Vertex, 4096);
    zhu.batch.init(vertexBuffer[0..3500], &commandBuffer);
    canvas = zhu.graphics.createRenderTarget(zhu.window.size);
    world = .init(zhu.assets.allocator);

    zhu.audio.init(44100 / 2, &soundBuffer);

    zhu.assets.loadAtlas(@import("zon/atlas.zon"));
    zhu.batch.circleImage = zhu.getImage("circle.png").?;
    const area: zhu.Rect = .init(.xy(16, 16), .xy(32, 32));
    zhu.batch.whiteImage = zhu.batch.circleImage.sub(area);

    const fontImage = zhu.assets.loadImage("assets/font.png", .zero);
    zhu.text.init(fontImage, @import("zon/font.zon"));

    zhu.window.bindAndUseMouseIcon("assets/farm-rpg/UI/cursor.png", .{});

    ui.init();
    context.init();
    map.init();
    factory.init();
    scene.init(&world);
}

var debug: bool = false;
pub fn frame(delta: f32) void {
    if (zhu.key.released(.X)) debug = !debug;
    scene.update(&world, delta);

    zhu.batch.beginDraw();
    const color: zhu.Color = .rgb(0.23, 0.31, 0.27);
    switch (context.scene.current) {
        .title => {
            zhu.batch.useTarget(color, .{});
            scene.draw(&world);
        },
        .farm => {
            zhu.batch.useTarget(color, .{ .target = &canvas });
            scene.draw(&world);

            zhu.batch.useTarget(color, .{});
            zhu.batch.drawImage(canvas.image, .zero, .{
                .mode = .window,
            });
        },
    }
    if (debug) zhu.debug.draw();
    zhu.batch.endDraw();
}

pub fn deinit() void {
    scene.deinit();
    map.deinit();
    context.deinit();
    ui.deinit();
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
        .size = .xy(1280, 720),
        .logicSize = .xy(640, 360),
        .scaleEnum = .fit,
    });
}
