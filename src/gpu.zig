const std = @import("std");

const sk = @import("sokol");
const math = @import("math.zig");

pub const Rectangle = math.Rectangle;

pub const Texture = struct {
    image: sk.gfx.Image,
    area: Rectangle = .{},

    pub fn width(self: *const Texture) f32 {
        return self.size().x;
    }

    pub fn height(self: *const Texture) f32 {
        return self.size().y;
    }

    pub fn size(self: *const Texture) math.Vector {
        return self.area.size();
    }

    pub fn subTexture(self: *const Texture, area: Rectangle) Texture {
        return Texture{ .image = self.image, .area = .{
            .min = self.area.min.add(area.min),
            .max = self.area.min.add(area.max),
        } };
    }

    pub fn mapTexture(self: *const Texture, area: Rectangle) Texture {
        return Texture{ .image = self.image, .area = area };
    }

    pub fn deinit(self: *Texture) void {
        sk.gfx.destroyImage(self.image);
    }
};

fn queryTextureSize(image: sk.gfx.Image) math.Vector {
    return math.Vector{
        .x = @floatFromInt(sk.gfx.queryImageWidth(image)),
        .y = @floatFromInt(sk.gfx.queryImageHeight(image)),
    };
}

pub const asRange = sk.gfx.asRange;
pub const queryBackend = sk.gfx.queryBackend;
pub const Buffer = sk.gfx.Buffer;
pub const Color = sk.gfx.Color;
pub const Sampler = sk.gfx.Sampler;
pub const Shader = sk.gfx.Shader;
pub const VertexLayout = sk.gfx.VertexLayoutState;

pub fn createBuffer(desc: sk.gfx.BufferDesc) Buffer {
    return sk.gfx.makeBuffer(desc);
}

pub const RenderPipelineDesc = struct {
    shader: sk.gfx.Shader,
    vertexLayout: VertexLayout,
    primitive: sk.gfx.PrimitiveType = .TRIANGLES,
    color: sk.gfx.ColorTargetState = .{},
    index_type: sk.gfx.IndexType = .DEFAULT,
    depth: sk.gfx.DepthState = .{},
};

pub fn createRenderPipeline(desc: RenderPipelineDesc) RenderPipeline {
    return .{ .value = sk.gfx.makePipeline(.{
        .shader = desc.shader,
        .layout = desc.vertexLayout,
        .primitive_type = desc.primitive,
        .colors = init: {
            var c: [4]sk.gfx.ColorTargetState = @splat(.{});
            c[0] = desc.color;
            break :init c;
        },
        .index_type = desc.index_type,
        .depth = desc.depth,
    }) };
}

pub fn createShaderModule(desc: sk.gfx.ShaderDesc) sk.gfx.Shader {
    return sk.gfx.makeShader(desc);
}

pub fn createSampler(desc: sk.gfx.SamplerDesc) Sampler {
    return sk.gfx.makeSampler(desc);
}

pub const BindGroup = struct {
    value: sk.gfx.Bindings = .{},

    pub fn bindIndexBuffer(self: *BindGroup, buffer: Buffer) void {
        self.value.index_buffer = buffer;
    }

    pub fn bindVertexBuffer(self: *BindGroup, index: u32, buffer: Buffer) void {
        self.value.vertex_buffers[index] = buffer;
    }

    pub fn bindTexture(self: *BindGroup, index: u32, texture: Texture) void {
        self.value.images[index] = texture.image;
    }

    pub fn bindSampler(self: *BindGroup, index: u32, sampler: Sampler) void {
        self.value.samplers[index] = sampler;
    }
};

pub const CommandEncoder = struct {
    pub fn beginRenderPass(_: CommandEncoder, color: Color) RenderPassEncoder {
        var action = sk.gfx.PassAction{};
        action.colors[0] = .{ .load_action = .CLEAR, .clear_value = color };
        sk.gfx.beginPass(.{ .action = action, .swapchain = sk.glue.swapchain() });
        return RenderPassEncoder{};
    }

    pub fn submit(_: *CommandEncoder) void {
        sk.gfx.commit();
    }
};

pub const RenderPassEncoder = struct {
    pub fn setPipeline(self: *RenderPassEncoder, pipeline: RenderPipeline) void {
        _ = self;
        sk.gfx.applyPipeline(pipeline.value);
    }

    pub fn setBindGroup(self: *RenderPassEncoder, group: BindGroup) void {
        _ = self;
        sk.gfx.applyBindings(group.value);
    }

    pub fn setUniform(self: *RenderPassEncoder, index: u32, uniform: anytype) void {
        _ = self;
        sk.gfx.applyUniforms(index, sk.gfx.asRange(&uniform));
    }

    pub fn draw(self: *RenderPassEncoder, number: u32) void {
        _ = self;
        sk.gfx.draw(0, number, 1);
    }

    pub fn end(self: *RenderPassEncoder) void {
        _ = self;
        sk.gfx.endPass();
    }
};

pub const DrawOptions = struct {
    texture: Texture,
    sourceRect: Rectangle,
    targetRect: Rectangle,
    radians: f32 = 0,
    pivot: math.Vector = .zero,
    alpha: f32 = 1,
};

pub fn draw(renderPass: *RenderPassEncoder, bind: *BindGroup, options: DrawOptions) void {
    const dst = options.targetRect;

    const size = queryTextureSize(options.texture.image);
    if (size.approx(.zero)) return;

    const min = options.sourceRect.min.div(size);
    const max = options.sourceRect.max.div(size);

    var vertex = [_]math.Vector3{
        .{ .x = dst.min.x, .y = dst.max.y },
        .{ .x = dst.max.x, .y = dst.max.y },
        .{ .x = dst.max.x, .y = dst.min.y },
        .{ .x = dst.min.x, .y = dst.min.y },
    };

    if (options.radians != 0) {
        const percent = options.pivot.div(size);
        const pivot = dst.min.add(percent.mul(dst.size()));

        for (&vertex) |*point| {
            point.* = pivot.add(point.sub(pivot).rotate(options.radians));
        }
    }

    const vertexes = [_]f32{
        // 顶点和颜色
        vertex[0].x, vertex[0].y, 0.5, 1.0, 1.0, 1.0, options.alpha, min.x, max.y, // 左上
        vertex[1].x, vertex[1].y, 0.5, 1.0, 1.0, 1.0, options.alpha, max.x, max.y, // 右上
        vertex[2].x, vertex[2].y, 0.5, 1.0, 1.0, 1.0, options.alpha, max.x, min.y, // 右下
        vertex[3].x, vertex[3].y, 0.5, 1.0, 1.0, 1.0, options.alpha, min.x, min.y, // 左下
    };

    const vertexBuffer = sk.gfx.makeBuffer(.{
        .data = sk.gfx.asRange(&vertexes),
    });

    bind.bindVertexBuffer(0, vertexBuffer);
    renderPass.setBindGroup(bind.*);

    sk.gfx.draw(0, 6, 1);
    sk.gfx.destroyBuffer(vertexBuffer);
}

pub const RenderPipeline = struct {
    value: sk.gfx.Pipeline,
};
