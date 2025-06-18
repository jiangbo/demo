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

pub fn queryTextureSize(image: sk.gfx.Image) math.Vector {
    return math.Vector{
        .x = @floatFromInt(sk.gfx.queryImageWidth(image)),
        .y = @floatFromInt(sk.gfx.queryImageHeight(image)),
    };
}

pub const RenderPipeline = sk.gfx.Pipeline;
pub const asRange = sk.gfx.asRange;
pub const queryBackend = sk.gfx.queryBackend;
pub const Buffer = sk.gfx.Buffer;
pub const Color = sk.gfx.Color;
pub var nearestSampler: sk.gfx.Sampler = undefined;
pub var linearSampler: sk.gfx.Sampler = undefined;

pub fn init() void {
    nearestSampler = sk.gfx.makeSampler(.{});
    linearSampler = sk.gfx.makeSampler(.{
        .min_filter = .LINEAR,
        .mag_filter = .LINEAR,
    });
}

pub fn begin(color: sk.gfx.Color) void {
    var action = sk.gfx.PassAction{};
    action.colors[0] = .{ .load_action = .CLEAR, .clear_value = color };
    sk.gfx.beginPass(.{ .action = action, .swapchain = sk.glue.swapchain() });
}

pub fn setPipeline(pipeline: RenderPipeline) void {
    sk.gfx.applyPipeline(pipeline);
}

pub fn setUniform(index: u32, uniform: anytype) void {
    sk.gfx.applyUniforms(index, sk.gfx.asRange(&uniform));
}

pub fn setBindGroup(group: BindGroup) void {
    sk.gfx.applyBindings(group.value);
}

pub fn drawInstanced(number: u32) void {
    sk.gfx.draw(0, 6, number);
}

pub fn end() void {
    sk.gfx.endPass();
    sk.gfx.commit();
}

pub fn createTexture(size: math.Vector, data: []const u8) Texture {
    return Texture{
        .image = sk.gfx.makeImage(.{
            .data = init: {
                var imageData = sk.gfx.ImageData{};
                imageData.subimage[0][0] = sk.gfx.asRange(data);
                break :init imageData;
            },
            .width = @intFromFloat(size.x),
            .height = @intFromFloat(size.y),
            .pixel_format = .RGBA8,
        }),
        .area = .init(.zero, size),
    };
}

pub fn createBuffer(desc: sk.gfx.BufferDesc) Buffer {
    return sk.gfx.makeBuffer(desc);
}

pub const QuadVertex = extern struct {
    position: math.Vector3, // 顶点坐标
    rotation: f32 = 0, // 旋转角度
    size: math.Vector2, // 大小
    pivot: math.Vector2 = .zero, // 旋转中心
    texture: math.Vector4, // 纹理坐标
    color: math.Vector4 = .one, // 顶点颜色
};

pub fn createQuadPipeline(shaderDesc: sk.gfx.ShaderDesc) RenderPipeline {
    var vertexLayout = sk.gfx.VertexLayoutState{};
    vertexLayout.attrs[0].format = .FLOAT3;
    vertexLayout.attrs[1].format = .FLOAT;
    vertexLayout.attrs[2].format = .FLOAT2;
    vertexLayout.attrs[3].format = .FLOAT2;
    vertexLayout.attrs[4].format = .FLOAT4;
    vertexLayout.attrs[5].format = .FLOAT4;
    vertexLayout.buffers[0].step_func = .PER_INSTANCE;

    return sk.gfx.makePipeline(.{
        .shader = sk.gfx.makeShader(shaderDesc),
        .layout = vertexLayout,
        .colors = init: {
            var c: [4]sk.gfx.ColorTargetState = @splat(.{});
            c[0] = .{ .blend = .{
                .enabled = true,
                .src_factor_rgb = .SRC_ALPHA,
                .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
            } };
            break :init c;
        },
    });
}

pub fn appendBuffer(buffer: Buffer, data: anytype) void {
    _ = sk.gfx.appendBuffer(buffer, sk.gfx.asRange(data));
}

pub const BindGroup = struct {
    value: sk.gfx.Bindings = .{},

    pub fn setVertexBuffer(self: *BindGroup, buffer: Buffer) void {
        self.value.vertex_buffers[0] = buffer;
    }

    pub fn setVertexOffset(self: *BindGroup, offset: u32) void {
        self.value.vertex_buffer_offsets[0] = @intCast(offset);
    }

    pub fn setTexture(self: *BindGroup, texture: Texture) void {
        self.value.images[0] = texture.image;
    }

    pub fn setSampler(self: *BindGroup, sampler: sk.gfx.Sampler) void {
        self.value.samplers[0] = sampler;
    }
};
