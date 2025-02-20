const std = @import("std");
const gfx = @import("graphics.zig");
const cache = @import("cache.zig");

var bind: gfx.BindGroup = .{};

const NUMBER = 1;

fn init() void {
    cache.init(allocator);

    const texture = cache.TextureCache.get("assets/player.bmp").?;
    bind.bindTexture(texture);

    storageBuffer = allocator.alloc(gfx.BatchInstance, NUMBER) catch unreachable;
    bind.bindStorageBuffer(0, storageBuffer);

    const camera = gfx.Camera.init(width, height);
    bind.bindUniformBuffer(gfx.UniformParams{ .vp = camera.vp() });
}

var storageBuffer: []gfx.BatchInstance = undefined;

fn fillVertex(idx: usize, x: f32, y: f32, w: f32, h: f32) void {
    storageBuffer[idx] = .{
        .position = .{ x, y, 0.5, 1.0 },
        .rotation = 0.0,
        .width = w,
        .height = h,
        .padding = 0.0,
        .texcoord = .{ 0.0, 0.0, 1.0, 1.0 },
        .color = .{ 1.0, 1.0, 1.0, 1.0 },
    };
}

fn frame() void {
    var renderPass = gfx.RenderPass.begin(.{ .r = 1, .b = 1, .a = 1 });
    defer renderPass.end();

    const texture = cache.TextureCache.get("assets/player.bmp").?;
    for (0..NUMBER) |i| {
        const x = rand.float(f32) * width * 0;
        const y = rand.float(f32) * height * 0;
        fillVertex(i, x, y, texture.width, texture.height);
    }

    bind.updateStorageBuffer(0, storageBuffer);
    renderPass.setPipeline(gfx.RenderPipeline.getTexturePipeline());
    renderPass.setBindGroup(0, bind);

    renderPass.draw(6 * NUMBER);
}

fn event(evt: ?*const gfx.Event) void {
    _ = evt;
}

fn deinit() void {
    allocator.free(storageBuffer);
    cache.deinit();
}

const width = 640;
const height = 480;
var rand: std.Random = undefined;
var allocator: std.mem.Allocator = undefined;

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    allocator = gpa.allocator();

    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    rand = prng.random();
    gfx.run(.{
        .width = width,
        .height = height,
        .title = "学习 sokol",
        .init = init,
        .event = event,
        .frame = frame,
        .deinit = deinit,
    });
}
