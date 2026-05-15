const std = @import("std");
const builtin = @import("builtin");
const zhu = @import("zhu");

const context = @import("context.zig");
const events = @import("event.zig");
const gui = @import("gui.zig");
const map = @import("map.zig");
const scene = @import("scene.zig");
const spawn = @import("spawn.zig");

var vertexBuffer: []zhu.batch.Vertex = undefined;
var commandBuffer: [128]zhu.batch.Command = undefined;
var world: zhu.ecs.World = undefined;

pub fn init() void {
    vertexBuffer = zhu.assets.oomAlloc(zhu.batch.Vertex, 4096);
    zhu.batch.init(vertexBuffer, &commandBuffer);
    zhu.batch.whiteImage = zhu.assets.createWhiteImage("farm/white");
    world = .init(zhu.assets.allocator);

    gui.init();
    context.init();
    events.init();
    map.init();
    spawn.init();
    scene.init();
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
    spawn.deinit();
    map.deinit();
    events.deinit();
    context.deinit();
    gui.deinit();
    world.deinit();
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
