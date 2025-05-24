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

vertexBuffer: []gpu.Vertex = undefined,
buffer: gpu.Buffer = undefined,

batchDrawCount: u32 = 0,

pub fn init(rect: math.Rectangle, border: math.Vector, vertexBuffer: []gpu.Vertex, indexBuffer: []u16) Camera {
    var self: Camera = .{ .rect = rect, .border = border };

    self.matrix = .{
        2 / rect.size().x, 0.0,                0.0, 0.0,
        0.0,               2 / -rect.size().y, 0.0, 0.0,
        0.0,               0.0,                1,   0.0,
        -1,                1,                  0,   1.0,
    };

    self.bindGroup.bindIndexBuffer(gpu.createBuffer(.{
        .type = .INDEXBUFFER,
        .data = gpu.asRange(indexBuffer),
    }));

    self.buffer = gpu.createBuffer(.{
        .type = .VERTEXBUFFER,
        .size = @sizeOf(gpu.Vertex) * vertexBuffer.len,
        .usage = .STREAM,
    });

    self.vertexBuffer = vertexBuffer;

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
    // sgl.defaults();
    // sgl.loadMatrix(@ptrCast(&self.matrix));
    self.batchDrawCount = 0;
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

pub fn batchDraw(self: *Camera, texture: gpu.Texture, position: math.Vector) void {
    const size = gpu.queryTextureSize(texture.image);
    if (size.approx(.zero)) return;

    const sourceRect = texture.area;
    const min = sourceRect.min.div(size);
    const max = sourceRect.max.div(size);

    self.vertexBuffer[self.batchDrawCount * 4 + 0] = .{
        .position = position.addY(texture.size().y),
        .uv = .init(min.x, max.y),
    };

    self.vertexBuffer[self.batchDrawCount * 4 + 1] = .{
        .position = position.add(texture.size()),
        .uv = .init(max.x, max.y),
    };

    self.vertexBuffer[self.batchDrawCount * 4 + 2] = .{
        .position = position.addX(texture.size().x),
        .uv = .init(max.x, min.y),
    };

    self.vertexBuffer[self.batchDrawCount * 4 + 3] = .{
        .position = position,
        .uv = .init(min.x, min.y),
    };

    self.bindGroup.bindTexture(shader.IMG_tex, texture);
    self.batchDrawCount += 1;
}

const sk = @import("sokol");
pub fn endDraw(self: *Camera) void {
    // sgl.draw();

    if (self.batchDrawCount != 0) {
        for (self.vertexBuffer) |*value| {
            value.position.z = 0;
        }

        sk.gfx.updateBuffer(self.buffer, sk.gfx.asRange(self.vertexBuffer));

        self.bindGroup.bindVertexBuffer(0, self.buffer);
        self.renderPass.setPipeline(self.pipeline);
        self.renderPass.setUniform(shader.UB_vs_params, .{ .vp = self.matrix });
        self.renderPass.setBindGroup(self.bindGroup);
        sk.gfx.draw(0, 6 * self.batchDrawCount, 1);
    }

    self.renderPass.end();
    gpu.commandEncoder.submit();
}
