const std = @import("std");

const cache = @import("cache.zig");
const window = @import("window.zig");
const gfx = @import("graphics.zig");

var runAnimation: gfx.FrameAnimation = undefined;

pub fn init() void {
    cache.init(allocator);
    gfx.init(window.width, window.height);

    runAnimation = .load("assets/enemy/run/{}.png", 8);
}

pub fn event(ev: *const window.Event) void {
    _ = ev;
}

pub fn update() void {
    const delta = window.deltaMillisecond();
    runAnimation.update(delta);
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    gfx.draw(gfx.loadTexture("assets/background.png"), 0, 0);
    gfx.play(&runAnimation, 500, 500);
}

pub fn deinit() void {
    cache.deinit();
}

var allocator: std.mem.Allocator = undefined;

pub fn main() void {
    var debugAllocator = std.heap.DebugAllocator(.{}).init;
    defer _ = debugAllocator.deinit();

    allocator = debugAllocator.allocator();
    window.width = 1280;
    window.height = 720;

    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    window.rand = prng.random();

    window.run(.{
        .title = "空洞武士",
        .init = init,
        .event = event,
        .update = update,
        .render = render,
        .deinit = deinit,
    });
}
