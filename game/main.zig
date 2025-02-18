const std = @import("std");
const sk = @import("sokol");
const stbi = @import("stbi");
const zm = @import("zmath");
const gfx = @import("graphics.zig");

const shd = @import("shader/test.glsl.zig");

const clearColor: sk.gfx.Color = .{ .r = 1, .b = 1, .a = 1 };
var info: sk.gfx.PassAction = undefined;
var pipeline: sk.gfx.Pipeline = undefined;
var bind: sk.gfx.Bindings = undefined;

var imageWidth: f32 = 0;
var imageHeight: f32 = 0;

export fn init() void {
    sk.gfx.setup(.{
        .environment = sk.glue.environment(),
        .logger = .{ .func = sk.log.func },
    });
    info.colors[0] = .{ .load_action = .CLEAR, .clear_value = clearColor };

    var image = stbi.Image.loadFromFile("assets/player.bmp", 4) catch unreachable;
    defer image.deinit();
    imageWidth = @floatFromInt(image.width);
    imageHeight = @floatFromInt(image.height);

    bind.vertex_buffers[0] = sk.gfx.makeBuffer(.{
        .data = sk.gfx.asRange(&vertex),
    });

    bind.index_buffer = sk.gfx.makeBuffer(.{
        .type = .INDEXBUFFER,
        .data = sk.gfx.asRange(&[_]u16{ 0, 1, 2, 0, 2, 3 }),
    });

    bind.images[shd.IMG_tex] = sk.gfx.allocImage();
    sk.gfx.initImage(bind.images[shd.IMG_tex], .{
        .width = @intCast(image.width),
        .height = @intCast(image.height),
        .pixel_format = .RGBA8,
        .data = init: {
            var data = sk.gfx.ImageData{};
            data.subimage[0][0] = sk.gfx.asRange(image.data);
            break :init data;
        },
    });

    bind.samplers[shd.SMP_smp] = sk.gfx.makeSampler(.{
        .min_filter = .LINEAR,
        .mag_filter = .LINEAR,
    });

    pipeline = sk.gfx.makePipeline(.{
        .shader = sk.gfx.makeShader(shd.testShaderDesc(sk.gfx.queryBackend())),
        .layout = init: {
            var l = sk.gfx.VertexLayoutState{};
            l.attrs[shd.ATTR_test_position].format = .FLOAT3;
            l.attrs[shd.ATTR_test_color0].format = .FLOAT3;
            l.attrs[shd.ATTR_test_texcoord0].format = .FLOAT2;
            break :init l;
        },
        .index_type = .UINT16,
        .depth = .{
            .compare = .LESS_EQUAL,
            .write_enabled = true,
        },
    });

    const camera = gfx.Camera.init(width, height);
    params = shd.VsParams{ .vp = camera.vp() };
}

var vertex: [8 * 4]f32 = undefined;

fn fillVertex(x: f32, y: f32, w: f32, h: f32) void {
    vertex = .{
        // 顶点和颜色
        x,     y + h, 0.5, 1.0, 1.0, 1.0, 0, 1,
        x + w, y + h, 0.5, 1.0, 1.0, 1.0, 1, 1,
        x + w, y,     0.5, 1.0, 1.0, 1.0, 1, 0,
        x,     y,     0.5, 1.0, 1.0, 1.0, 0, 0,
    };
}

var params: shd.VsParams = undefined;

export fn frame() void {
    sk.gfx.beginPass(.{ .action = info, .swapchain = sk.glue.swapchain() });

    sk.gfx.applyPipeline(pipeline);
    sk.gfx.applyUniforms(shd.UB_vs_params, sk.gfx.asRange(&params));

    for (0..5000) |_| {
        const x = rand.float(f32) * width;
        const y = rand.float(f32) * height;
        fillVertex(x, y, imageWidth, imageHeight);
        sk.gfx.destroyBuffer(bind.vertex_buffers[0]);
        bind.vertex_buffers[0] = sk.gfx.makeBuffer(.{
            .data = sk.gfx.asRange(&vertex),
        });
        sk.gfx.applyBindings(bind);
        sk.gfx.draw(0, 6, 1);
    }

    sk.gfx.endPass();
    sk.gfx.commit();
}

export fn cleanup() void {
    sk.gfx.shutdown();
}

const width = 640;
const height = 480;
var rand: std.Random = undefined;

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
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
        .swap_interval = 0,
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
    });
}
