const std = @import("std");
const sk = @import("sokol");
const stbi = @import("stbi");
const zm = @import("zmath");

const vec3 = @import("math.zig").Vec3;
const mat4 = @import("math.zig").Mat4;

const shd = @import("shader/test.glsl.zig");

const clearColor: sk.gfx.Color = .{ .r = 1, .b = 1, .a = 1 };
var info: sk.gfx.PassAction = undefined;
var pipeline: sk.gfx.Pipeline = undefined;
var bind: sk.gfx.Bindings = undefined;

export fn init() void {

    // 设置初始化环境
    sk.gfx.setup(.{
        .environment = sk.glue.environment(),
        .logger = .{ .func = sk.log.func },
    });

    // 背景清除颜色
    info.colors[0] = .{ .load_action = .CLEAR, .clear_value = clearColor };

    // 顶点数据
    bind.vertex_buffers[0] = sk.gfx.makeBuffer(.{
        .data = sk.gfx.asRange(&[_]f32{
            // 位置           颜色
            -1.0, -1.0, -1.0, 1.0, 0.0, 0.0, 1.0,
            1.0,  -1.0, -1.0, 1.0, 0.0, 0.0, 1.0,
            1.0,  1.0,  -1.0, 1.0, 0.0, 0.0, 1.0,
            -1.0, 1.0,  -1.0, 1.0, 0.0, 0.0, 1.0,

            -1.0, -1.0, 1.0,  0.0, 1.0, 0.0, 1.0,
            1.0,  -1.0, 1.0,  0.0, 1.0, 0.0, 1.0,
            1.0,  1.0,  1.0,  0.0, 1.0, 0.0, 1.0,
            -1.0, 1.0,  1.0,  0.0, 1.0, 0.0, 1.0,

            -1.0, -1.0, -1.0, 0.0, 0.0, 1.0, 1.0,
            -1.0, 1.0,  -1.0, 0.0, 0.0, 1.0, 1.0,
            -1.0, 1.0,  1.0,  0.0, 0.0, 1.0, 1.0,
            -1.0, -1.0, 1.0,  0.0, 0.0, 1.0, 1.0,

            1.0,  -1.0, -1.0, 1.0, 0.5, 0.0, 1.0,
            1.0,  1.0,  -1.0, 1.0, 0.5, 0.0, 1.0,
            1.0,  1.0,  1.0,  1.0, 0.5, 0.0, 1.0,
            1.0,  -1.0, 1.0,  1.0, 0.5, 0.0, 1.0,

            -1.0, -1.0, -1.0, 0.0, 0.5, 1.0, 1.0,
            -1.0, -1.0, 1.0,  0.0, 0.5, 1.0, 1.0,
            1.0,  -1.0, 1.0,  0.0, 0.5, 1.0, 1.0,
            1.0,  -1.0, -1.0, 0.0, 0.5, 1.0, 1.0,

            -1.0, 1.0,  -1.0, 1.0, 0.0, 0.5, 1.0,
            -1.0, 1.0,  1.0,  1.0, 0.0, 0.5, 1.0,
            1.0,  1.0,  1.0,  1.0, 0.0, 0.5, 1.0,
            1.0,  1.0,  -1.0, 1.0, 0.0, 0.5, 1.0,
        }),
    });

    // 索引数据
    bind.index_buffer = sk.gfx.makeBuffer(.{
        .type = .INDEXBUFFER,
        .data = sk.gfx.asRange(&[_]u16{
            0,  1,  2,  0,  2,  3,
            6,  5,  4,  7,  6,  4,
            8,  9,  10, 8,  10, 11,
            14, 13, 12, 15, 14, 12,
            16, 17, 18, 16, 18, 19,
            22, 21, 20, 23, 22, 20,
        }),
    });

    pipeline = sk.gfx.makePipeline(.{
        .shader = sk.gfx.makeShader(shd.testShaderDesc(sk.gfx.queryBackend())),
        .layout = init: {
            var l = sk.gfx.VertexLayoutState{};
            l.attrs[shd.ATTR_test_position].format = .FLOAT3;
            l.attrs[shd.ATTR_test_color0].format = .FLOAT4;
            break :init l;
        },
        .index_type = .UINT16,
        .depth = .{
            .compare = .LESS_EQUAL,
            .write_enabled = true,
        },
        .cull_mode = .BACK,
    });
}

const width = 800;
const height = 600;

var rx: f32 = 0;
var ry: f32 = 0;
const view: zm.Mat = zm.lookAtRh(
    zm.f32x4(0, 1.5, 6, 1.0), // eye position
    zm.f32x4(0.0, 0.0, 0.0, 1.0), // focus point
    zm.f32x4(0.0, 1.0, 0.0, 0.0), // up direction
);

export fn frame() void {
    const dt: f32 = @floatCast(sk.app.frameDuration() * 60);
    rx += 1.0 * dt;
    ry += 2.0 * dt;
    const params = computeParams();

    sk.gfx.beginPass(.{ .action = info, .swapchain = sk.glue.swapchain() });

    sk.gfx.applyPipeline(pipeline);
    sk.gfx.applyBindings(bind);

    sk.gfx.applyUniforms(shd.UB_vs_params, sk.gfx.asRange(&params));
    sk.gfx.draw(0, 36, 1);

    sk.gfx.endPass();
    sk.gfx.commit();
}

fn computeParams() shd.VsParams {
    // const rxm = zm.rotationX(rx);
    // const rym = zm.rotationY(ry);
    // const model = zm.mul(rxm, rym);

    // const aspect = sk.app.widthf() / sk.app.heightf();
    // const p = zm.perspectiveFovLh(60.0, aspect, 0.01, 10);

    // return shd.VsParams{ .vp = zm.mul(zm.mul(model, view), p) };

    const xm = mat4.rotate(rx, .{ .x = 1.0, .y = 0.0, .z = 0.0 });
    const ym = mat4.rotate(ry, .{ .x = 0.0, .y = 1.0, .z = 0.0 });
    const m = mat4.mul(xm, ym);
    std.log.info("m: {}", .{m});
    const aspect = sk.app.widthf() / sk.app.heightf();
    const proj = mat4.persp(60.0, aspect, 0.01, 10.0);

    return shd.VsParams{ .vp = zm.mul(zm.mul(convert(m), view), convert(proj)) };
}

fn convert(mvp: mat4) zm.Mat {
    return zm.Mat{
        zm.f32x4(mvp.m[0][0], mvp.m[0][1], mvp.m[0][2], mvp.m[0][3]),
        zm.f32x4(mvp.m[1][0], mvp.m[1][1], mvp.m[1][2], mvp.m[1][3]),
        zm.f32x4(mvp.m[2][0], mvp.m[2][1], mvp.m[2][2], mvp.m[2][3]),
        zm.f32x4(mvp.m[3][0], mvp.m[3][1], mvp.m[3][2], mvp.m[3][3]),
    };
}

export fn cleanup() void {
    sk.gfx.shutdown();
}

pub fn main() void {
    sk.app.run(.{
        .width = width,
        .height = height,
        .window_title = "学习 sokol",
        .logger = .{ .func = sk.log.func },
        .win32_console_attach = true,
        .sample_count = 4,
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
    });
}
