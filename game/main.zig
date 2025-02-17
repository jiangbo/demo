const std = @import("std");
const sk = @import("sokol");
const stbi = @import("stbi");
const zm = @import("zmath");

const shd = @import("shader/test.glsl.zig");

const clearColor: sk.gfx.Color = .{ .r = 1, .b = 1, .a = 1 };
var info: sk.gfx.PassAction = undefined;
var pipeline: sk.gfx.Pipeline = undefined;
var bind: sk.gfx.Bindings = undefined;

export fn init() void {
    sk.gfx.setup(.{
        .environment = sk.glue.environment(),
        .logger = .{ .func = sk.log.func },
    });
    info.colors[0] = .{ .load_action = .CLEAR, .clear_value = clearColor };

    var image = stbi.Image.loadFromFile("assets/player.bmp", 4) catch unreachable;
    defer image.deinit();
    const x: f32, const y: f32 = .{ 0, 0 };
    const w: f32 = @floatFromInt(image.width);
    const h: f32 = @floatFromInt(image.height);

    bind.vertex_buffers[0] = sk.gfx.makeBuffer(.{
        .data = sk.gfx.asRange(&[_]f32{
            // 顶点和颜色
            x,     y + h, 0, 1.0, 1.0, 1.0, 0, 1,
            x + w, y + h, 0, 1.0, 1.0, 1.0, 1, 1,
            x + w, y,     0, 1.0, 1.0, 1.0, 1, 0,
            x,     y,     0, 1.0, 1.0, 1.0, 0, 0,
        }),
    });

    bind.vertex_buffers[0] = sk.gfx.makeBuffer(.{
        .data = sk.gfx.asRange(&[_]f32{
            // 顶点和颜色
            -150, 150,  0, 1.0, 1.0, 1.0, 0, 0,
            150,  150,  0, 1.0, 1.0, 1.0, 1, 0,
            150,  -150, 0, 1.0, 1.0, 1.0, 1, 1,
            -150, -150, 0, 1.0, 1.0, 1.0, 0, 1,
        }),
    });

    // bind.vertex_buffers[0] = sk.gfx.makeBuffer(.{
    //     .data = sk.gfx.asRange(&[_]f32{
    //         // 顶点和颜色
    //         0,   300, 0, 1.0, 1.0, 1.0, 0, 0,
    //         300, 300, 0, 1.0, 1.0, 1.0, 1, 0,
    //         300, 0,   0, 1.0, 1.0, 1.0, 1, 1,
    //         0,   0,   0, 1.0, 1.0, 1.0, 0, 1,
    //     }),
    // });

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
}

const view = zm.lookAtLh(
    zm.f32x4(0, 0, -1, 0), // 眼睛所在位置
    zm.f32x4(0.0, 0.0, 0.0, 0), // 眼睛看向的位置
    zm.f32x4(0.0, 1.0, 0.0, 0), // 头顶方向
);

export fn frame() void {
    sk.gfx.beginPass(.{ .action = info, .swapchain = sk.glue.swapchain() });

    sk.gfx.applyPipeline(pipeline);
    sk.gfx.applyBindings(bind);

    // const vp = zm.mul(view, zm.orthographicLh(width, height, 0, 1));
    const vp = zm.mul(view, zm.orthographicOffCenterLh(0, width, 0, height, 0, 1));
    const params = shd.VsParams{ .view = zm.transpose(vp) };
    sk.gfx.applyUniforms(shd.UB_vs_params, sk.gfx.asRange(&params));
    sk.gfx.draw(0, 6, 1);

    sk.gfx.endPass();
    sk.gfx.commit();
}

export fn cleanup() void {
    sk.gfx.shutdown();
}

const width = 800;
const height = 600;

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    stbi.init(gpa.allocator());
    defer stbi.deinit();

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
