const std = @import("std");

const cache = @import("cache.zig");
const window = @import("window.zig");
const gfx = @import("graphics.zig");

var enemyRunAnimation: gfx.SliceFrameAnimation = undefined;
var playerRunAnimation: gfx.AtlasFrameAnimation = undefined;

pub fn init() void {
    cache.init(allocator);
    gfx.init(window.width, window.height);

    enemyRunAnimation = .load("assets/enemy/run/{}.png", 8);
    playerRunAnimation = .load("assets/player/run.png", 10);
}

pub fn event(ev: *const window.Event) void {
    _ = ev;
}

pub fn update() void {
    const delta = window.deltaMillisecond();
    enemyRunAnimation.update(delta);
    playerRunAnimation.update(delta);
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    gfx.draw(gfx.loadTexture("assets/background.png"), 0, 0);
    gfx.playSliceFlipX(&enemyRunAnimation, 0, 0, true);

    var x = window.width - enemyRunAnimation.textures[0].width();
    gfx.playSlice(&enemyRunAnimation, x, 0);

    const y = window.height - playerRunAnimation.texture.height();
    gfx.playAtlas(&playerRunAnimation, 0, y);

    x = window.width - playerRunAnimation.frames[0].w;
    gfx.playAtlasFlipX(&playerRunAnimation, x, y, true);
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
