const std = @import("std");
const sk = @import("sokol");

const render = @import("shader/single.glsl.zig");

pub const Color = sk.gfx.Color;
pub const Buffer = sk.gfx.Buffer;

pub const Texture = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32,
    height: f32,
    value: sk.gfx.Image,

    pub fn init(width: u32, height: u32, data: []u8) Texture {
        const image = sk.gfx.allocImage();

        sk.gfx.initImage(image, .{
            .width = @as(i32, @intCast(width)),
            .height = @as(i32, @intCast(height)),
            .pixel_format = .RGBA8,
            .data = init: {
                var imageData = sk.gfx.ImageData{};
                imageData.subimage[0][0] = sk.gfx.asRange(data);
                break :init imageData;
            },
        });

        return .{
            .width = @floatFromInt(width),
            .height = @floatFromInt(height),
            .value = image,
        };
    }
};

pub const BindGroup = struct {
    value: sk.gfx.Bindings = .{},
    uniform: render.VsParams = undefined,

    pub fn bindIndexBuffer(self: *BindGroup, buffer: Buffer) void {
        self.value.index_buffer = buffer;
    }

    pub fn bindVertexBuffer(self: *BindGroup, index: u32, buffer: Buffer) void {
        self.value.vertex_buffers[index] = buffer;
    }

    pub fn bindTexture(self: *BindGroup, index: u32, texture: Texture) void {
        self.value.images[index] = texture.value;
    }

    pub fn bindSampler(self: *BindGroup, index: u32, sampler: Sampler) void {
        self.value.samplers[index] = sampler.value;
    }

    pub fn bindUniformBuffer(self: *BindGroup, uniform: UniformParams) void {
        self.uniform = uniform;
    }
};

pub const CommandEncoder = struct {
    pub fn beginRenderPass(color: Color) RenderPassEncoder {
        return RenderPassEncoder.begin(color);
    }
};

pub const RenderPassEncoder = struct {
    pub fn begin(color: Color) RenderPassEncoder {
        var action = sk.gfx.PassAction{};
        action.colors[0] = .{ .load_action = .CLEAR, .clear_value = color };
        sk.gfx.beginPass(.{ .action = action, .swapchain = sk.glue.swapchain() });
        return RenderPassEncoder{};
    }

    pub fn setPipeline(self: *RenderPassEncoder, pipeline: RenderPipeline) void {
        _ = self;
        sk.gfx.applyPipeline(pipeline.value);
    }

    pub fn setBindGroup(self: *RenderPassEncoder, group: BindGroup) void {
        _ = self;
        sk.gfx.applyUniforms(render.UB_vs_params, sk.gfx.asRange(&group.uniform));
        sk.gfx.applyBindings(group.value);
    }

    pub fn draw(self: *RenderPassEncoder, number: u32) void {
        _ = self;
        sk.gfx.draw(0, number, 1);
    }

    pub fn submit(self: *RenderPassEncoder) void {
        _ = self;
        sk.gfx.endPass();
        sk.gfx.commit();
    }
};

const UniformParams = render.VsParams;

pub const Renderer = struct {
    bind: BindGroup,
    renderPass: RenderPassEncoder,

    var indexBuffer: ?Buffer = null;
    var pipeline: ?RenderPipeline = null;
    var sampler: ?Sampler = null;

    pub fn init() Renderer {
        var self = Renderer{ .bind = .{}, .renderPass = undefined };

        indexBuffer = indexBuffer orelse sk.gfx.makeBuffer(.{
            .type = .INDEXBUFFER,
            .data = sk.gfx.asRange(&[_]u16{ 0, 1, 2, 0, 2, 3 }),
        });
        self.bind.bindIndexBuffer(indexBuffer.?);

        sampler = sampler orelse Sampler.liner();
        self.bind.bindSampler(render.SMP_smp, sampler.?);

        pipeline = pipeline orelse RenderPipeline{
            .value = sk.gfx.makePipeline(.{
                .shader = sk.gfx.makeShader(render.singleShaderDesc(sk.gfx.queryBackend())),
                .layout = init: {
                    var l = sk.gfx.VertexLayoutState{};
                    l.attrs[render.ATTR_single_position].format = .FLOAT3;
                    l.attrs[render.ATTR_single_color0].format = .FLOAT3;
                    l.attrs[render.ATTR_single_texcoord0].format = .FLOAT2;
                    break :init l;
                },
                .colors = init: {
                    var c: [4]sk.gfx.ColorTargetState = @splat(.{});
                    c[0] = .{
                        .blend = .{
                            .enabled = true,
                            .src_factor_rgb = .SRC_ALPHA,
                            .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
                        },
                    };
                    break :init c;
                },
                .index_type = .UINT16,
                .depth = .{ .compare = .LESS_EQUAL, .write_enabled = true },
            }),
        };

        return self;
    }

    pub const DrawOptions = struct {
        uniform: UniformParams,
        x: f32 = 0,
        y: f32 = 0,
        texture: Texture,
        flipX: bool = false,
    };

    pub fn draw(self: *Renderer, options: DrawOptions) void {
        const w = options.texture.width;
        const h = options.texture.height;

        const texU0: f32 = if (options.flipX) 1 else 0;
        const texU1: f32 = if (options.flipX) 0 else 1;

        const vertexBuffer = sk.gfx.makeBuffer(.{
            .data = sk.gfx.asRange(&[_]f32{
                // 顶点和颜色
                options.x,     options.y + h, 0.5, 1.0, 1.0, 1.0, texU0, 1,
                options.x + w, options.y + h, 0.5, 1.0, 1.0, 1.0, texU1, 1,
                options.x + w, options.y,     0.5, 1.0, 1.0, 1.0, texU1, 0,
                options.x,     options.y,     0.5, 1.0, 1.0, 1.0, texU0, 0,
            }),
        });

        self.bind.bindVertexBuffer(0, vertexBuffer);
        self.bind.bindUniformBuffer(options.uniform);

        self.renderPass.setPipeline(pipeline.?);
        self.bind.bindTexture(render.IMG_tex, options.texture);
        self.renderPass.setBindGroup(self.bind);
        sk.gfx.draw(0, 6, 1);
        sk.gfx.destroyBuffer(vertexBuffer);
    }
};

pub const RenderPipeline = struct {
    value: sk.gfx.Pipeline,
};

pub const Sampler = struct {
    value: sk.gfx.Sampler,

    pub fn liner() Sampler {
        const sampler = sk.gfx.makeSampler(.{
            .min_filter = .LINEAR,
            .mag_filter = .LINEAR,
        });
        return .{ .value = sampler };
    }

    pub fn nearest() Sampler {
        const sampler = sk.gfx.makeSampler(.{
            .min_filter = .NEAREST,
            .mag_filter = .NEAREST,
        });
        return .{ .value = sampler };
    }
};
