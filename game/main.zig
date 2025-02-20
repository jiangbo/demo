const std = @import("std");
const gfx = @import("graphics.zig");
const cache = @import("cache.zig");
const context = @import("context.zig");

fn init() void {
    const allocator = context.allocator;
    cache.init(allocator);

    context.camera = gfx.Camera.init(context.width, context.height);
    _ = cache.TextureCache.get("assets/player.bmp").?;
    context.textureSampler = gfx.Sampler.liner();

    context.batchBuffer = gfx.BatchBuffer.init(allocator) catch unreachable;
}

fn frame() void {
    const texture = cache.TextureCache.get("assets/player.bmp").?;

    var batch = gfx.TextureBatch.begin(texture);
    defer batch.end();

    batch.draw(0, 0);
    batch.draw(200, 200);
}

fn event(evt: ?*const gfx.Event) void {
    _ = evt;
}

fn deinit() void {
    cache.deinit();
    context.batchBuffer.deinit(context.allocator);
}

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    context.allocator = gpa.allocator();

    context.width = 640;
    context.height = 480;

    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    context.rand = prng.random();
    gfx.run(.{ .init = init, .event = event, .frame = frame, .deinit = deinit });
}
