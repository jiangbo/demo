const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const shader = @import("shader/single.glsl.zig");

const Camera = @This();

rect: math.Rectangle,
border: math.Vector,
matrix: [16]f32 = undefined,
renderPass: gpu.RenderPassEncoder = undefined,
bindGroup: gpu.BindGroup = .{},
pipeline: gpu.RenderPipeline = undefined,

pub fn init(rect: math.Rectangle, border: math.Vector) Camera {
    var self: Camera = .{ .rect = rect, .border = border };

    self.matrix = .{
        2 / rect.size().x, 0.0,                0.0, 0.0,
        0.0,               2 / -rect.size().y, 0.0, 0.0,
        0.0,               0.0,                1,   0.0,
        -1,                1,                  0,   1.0,
    };

    self.bindGroup.bindIndexBuffer(gpu.createBuffer(.{
        .type = .INDEXBUFFER,
        .data = gpu.asRange(&[_]u16{ 0, 1, 2, 0, 2, 3 }),
    }));

    self.bindGroup.bindSampler(shader.SMP_smp, gpu.createSampler(.{}));
    self.pipeline = initPipeline();
    return self;
}

fn initPipeline() gpu.RenderPipeline {
    var vertexLayout = gpu.VertexLayout{};
    vertexLayout.attrs[shader.ATTR_single_position].format = .FLOAT3;
    vertexLayout.attrs[shader.ATTR_single_color0].format = .FLOAT4;
    vertexLayout.attrs[shader.ATTR_single_texcoord0].format = .FLOAT2;

    const shaderDesc = shader.singleShaderDesc(gpu.queryBackend());
    return gpu.createRenderPipeline(.{
        .shader = gpu.createShaderModule(shaderDesc),
        .vertexLayout = vertexLayout,
        .color = .{ .blend = .{
            .enabled = true,
            .src_factor_rgb = .SRC_ALPHA,
            .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
        } },
        .index_type = .UINT16,
        .depth = .{ .compare = .LESS_EQUAL, .write_enabled = true },
    });
}

pub fn lookAt(self: *Camera, pos: math.Vector) void {
    const half = self.rect.size().scale(0.5);

    const max = self.border.sub(self.rect.size());
    const offset = pos.sub(half).clamp(.zero, max);

    self.rect = .init(offset, self.rect.size());
}

const sgl = @import("sokol").gl;
pub fn beginDraw(self: *Camera, color: gpu.Color) void {
    self.renderPass = gpu.commandEncoder.beginRenderPass(color);
    sgl.defaults();
    sgl.loadMatrix(@ptrCast(&self.matrix));
}

pub fn draw(self: *Camera, tex: gpu.Texture, position: math.Vector) void {
    self.drawFlipX(tex, position, false);
}

pub fn drawFlipX(self: *Camera, tex: gpu.Texture, pos: math.Vector, flipX: bool) void {
    const target: math.Rectangle = .init(pos, tex.size());
    var src = tex.area;
    if (flipX) {
        src.min.x = tex.area.max.x;
        src.max.x = tex.area.min.x;
    }

    self.drawOptions(.{ .texture = tex, .sourceRect = src, .targetRect = target });
}

pub const DrawOptions = gpu.DrawOptions;
pub fn drawOptions(self: *Camera, options: DrawOptions) void {
    self.matrix[12] = -1 - self.rect.min.x * self.matrix[0];
    self.matrix[13] = 1 - self.rect.min.y * self.matrix[5];

    // var src = options.sourceRect;
    // if (src.min.approx(.zero) and src.max.approx(.zero)) {
    //     src = options.texture.area;
    // }

    self.renderPass.setPipeline(self.pipeline);
    self.renderPass.setUniform(shader.UB_vs_params, .{ .vp = self.matrix });
    self.bindGroup.bindTexture(shader.IMG_tex, options.texture);

    gpu.draw(&self.renderPass, &self.bindGroup, options);
}

pub fn endDraw(self: *Camera) void {
    sgl.draw();
    self.renderPass.end();
    gpu.commandEncoder.submit();
}
