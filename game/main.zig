const std = @import("std");
const sk = @import("sokol");
const stbi = @import("stbi");
const zm = @import("zmath");
const gfx = @import("graphics.zig");

const shd = @import("shader/test.glsl.zig");

var bind: gfx.BindGroup = .{};

var imageWidth: f32 = 0;
var imageHeight: f32 = 0;
const NUMBER = 10000;

export fn init() void {
    sk.gfx.setup(.{
        .environment = sk.glue.environment(),
        .logger = .{ .func = sk.log.func },
    });

    var image = stbi.Image.loadFromFile("assets/player.bmp", 4) catch unreachable;
    defer image.deinit();
    imageWidth = @floatFromInt(image.width);
    imageHeight = @floatFromInt(image.height);

    bind.bindImage(image.width, image.height, image.data);
    storageBuffer = allocator.alloc(shd.Batchinstance, NUMBER) catch unreachable;
    bind.bindStorageBuffer(0, storageBuffer);

    const camera = gfx.Camera.init(width, height);
    params = shd.VsParams{ .vp = camera.vp() };
}

var storageBuffer: []shd.Batchinstance = undefined;

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

var params: shd.VsParams = undefined;

export fn frame() void {
    var encoder = gfx.CommandEncoder{};
    defer encoder.finish();

    var renderPass = encoder.beginRenderPass(.{ .r = 1, .b = 1, .a = 1 });
    defer renderPass.end();

    renderPass.setPipeline(gfx.RenderPipeline.getTexturePipeline());
    sk.gfx.applyUniforms(shd.UB_vs_params, sk.gfx.asRange(&params));

    for (0..NUMBER) |i| {
        const x = rand.float(f32) * width;
        const y = rand.float(f32) * height;
        fillVertex(i, x, y, imageWidth, imageHeight);
    }

    bind.updateStorageBuffer(0, storageBuffer);
    renderPass.setBindGroup(0, bind);

    renderPass.draw(6 * NUMBER);
}

export fn cleanup() void {
    sk.gfx.shutdown();
    allocator.free(storageBuffer);
}

const width = 640;
const height = 480;
var rand: std.Random = undefined;
var allocator: std.mem.Allocator = undefined;

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    allocator = gpa.allocator();
    stbi.init(gpa.allocator());
    defer stbi.deinit();

    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    rand = prng.random();
    sk.app.run(.{
        .width = width,
        .height = height,
        .window_title = "学习 sokol",
        .logger = .{ .func = sk.log.func },
        .win32_console_attach = true,
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
    });
}
