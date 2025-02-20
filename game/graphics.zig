const std = @import("std");
const zm = @import("zmath");
const sk = @import("sokol");

const context = @import("context.zig");

const shd = @import("shader/test.glsl.zig");

pub const Camera = struct {
    view: zm.Mat,
    proj: zm.Mat,

    pub fn init(width: f32, height: f32) Camera {
        return .{
            .view = zm.lookAtLh(
                zm.f32x4(0, 0, 0, 0), // 眼睛所在位置
                zm.f32x4(0, 0, 1, 0), // 眼睛看向的位置
                zm.f32x4(0, 1, 0, 0), // 头顶方向
            ),
            .proj = zm.orthographicOffCenterLh(0, width, 0, height, 0, 1),
        };
    }

    pub fn vp(self: Camera) zm.Mat {
        return zm.mul(self.view, self.proj);
    }
};

pub const BatchInstance = shd.Batchinstance;
pub const UniformParams = shd.VsParams;
pub const Image = sk.gfx.Image;
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

pub const Color = sk.gfx.Color;
pub const Buffer = sk.gfx.Buffer;

pub const BindGroup = struct {
    value: sk.gfx.Bindings = .{},
    uniform: shd.VsParams = undefined,

    pub fn bindTexture(self: *BindGroup, texture: Texture) void {
        self.value.images[shd.IMG_tex] = texture.value;
    }

    pub fn bindStorageBuffer(self: *BindGroup, index: u32, buffer: Buffer) void {
        self.value.storage_buffers[index] = buffer;
    }

    pub fn updateStorageBuffer(self: *BindGroup, index: u32, buffer: anytype) void {
        const range = sk.gfx.asRange(buffer);
        sk.gfx.updateBuffer(self.value.storage_buffers[index], range);
    }

    pub fn bindUniformBuffer(self: *BindGroup, uniform: UniformParams) void {
        self.uniform = uniform;
    }
};

pub const CommandEncoder = struct {};

pub const RenderPass = struct {
    pub fn begin(color: Color) RenderPass {
        var action = sk.gfx.PassAction{};
        action.colors[0] = .{ .clear_value = color };
        sk.gfx.beginPass(.{ .action = action, .swapchain = sk.glue.swapchain() });
        return RenderPass{};
    }

    pub fn setPipeline(self: *RenderPass, pipeline: RenderPipeline) void {
        _ = self;
        sk.gfx.applyPipeline(pipeline.value);
    }

    pub fn setBindGroup(self: *RenderPass, group: BindGroup) void {
        _ = self;
        sk.gfx.applyUniforms(shd.UB_vs_params, sk.gfx.asRange(&group.uniform));
        sk.gfx.applyBindings(group.value);
    }

    pub fn draw(self: *RenderPass, number: u32) void {
        _ = self;
        sk.gfx.draw(0, number, 1);
    }

    pub fn end(self: *RenderPass) void {
        _ = self;
        sk.gfx.endPass();
        sk.gfx.commit();
    }
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

const Allocator = std.mem.Allocator;

pub const BatchBuffer = struct {
    const size: usize = 100;

    cpu: std.ArrayListUnmanaged(BatchInstance),
    gpu: Buffer,

    pub fn init(alloc: Allocator) Allocator.Error!BatchBuffer {
        return .{
            .cpu = try std.ArrayListUnmanaged(BatchInstance).initCapacity(alloc, size),
            .gpu = sk.gfx.makeBuffer(.{
                .type = .STORAGEBUFFER,
                .usage = .DYNAMIC,
                .size = size * @sizeOf(BatchInstance),
            }),
        };
    }

    pub fn deinit(self: *BatchBuffer, alloc: Allocator) void {
        self.cpu.deinit(alloc);
    }
};

pub const TextureBatch = struct {
    bind: BindGroup,
    texture: Texture,
    pipeline: RenderPipeline,
    renderPass: RenderPass,
    buffer: BatchBuffer,

    pub fn begin(tex: Texture) TextureBatch {
        var textureBatch = TextureBatch{
            .bind = .{},
            .pipeline = RenderPipeline.getTexturePipeline(),
            .texture = tex,
            .renderPass = RenderPass.begin(context.clearColor),
            .buffer = context.batchBuffer,
        };

        textureBatch.bind.bindUniformBuffer(UniformParams{ .vp = context.camera.vp() });
        textureBatch.bind.bindStorageBuffer(0, textureBatch.buffer.gpu);
        textureBatch.bind.bindTexture(tex);

        const sampler = context.textureSampler.value;
        textureBatch.bind.value.samplers[shd.SMP_smp] = sampler;

        return textureBatch;
    }

    pub fn draw(self: *TextureBatch, x: f32, y: f32) void {
        self.buffer.cpu.appendAssumeCapacity(.{
            .position = .{ x, y, 0.5, 1.0 },
            .rotation = 0.0,
            .width = self.texture.width,
            .height = self.texture.height,
            .padding = 0.0,
            .texcoord = .{ 0.0, 0.0, 1.0, 1.0 },
            .color = .{ 1.0, 1.0, 1.0, 1.0 },
        });
    }

    pub fn end(self: *TextureBatch) void {
        self.renderPass.setPipeline(self.pipeline);
        self.bind.updateStorageBuffer(0, self.buffer.cpu.items);
        self.renderPass.setBindGroup(self.bind);
        self.renderPass.draw(6 * @as(u32, @intCast(self.buffer.cpu.items.len)));
        self.renderPass.end();
    }
};

pub const RenderPipeline = struct {
    value: sk.gfx.Pipeline,
    pub var texturePipeline: ?RenderPipeline = null;

    pub fn getTexturePipeline() RenderPipeline {
        if (texturePipeline) |p| return p;

        const pip = sk.gfx.makePipeline(.{
            .shader = sk.gfx.makeShader(shd.testShaderDesc(sk.gfx.queryBackend())),
            .depth = .{
                .compare = .LESS_EQUAL,
                .write_enabled = true,
            },
        });
        texturePipeline = RenderPipeline{ .value = pip };
        return texturePipeline.?;
    }
};

pub const Event = sk.app.Event;
pub const RunInfo = struct {
    init: *const fn () void,
    frame: *const fn () void,
    event: *const fn (?*const Event) void,
    deinit: *const fn () void,
};

var runInfo: RunInfo = undefined;
pub fn run(info: RunInfo) void {
    runInfo = info;
    sk.app.run(.{
        .width = @as(i32, @intFromFloat(context.width)),
        .height = @as(i32, @intFromFloat(context.height)),
        .window_title = context.title,
        .logger = .{ .func = sk.log.func },
        .win32_console_attach = true,
        .high_dpi = true,
        .init_cb = init,
        .event_cb = event,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
    });
}

export fn init() void {
    sk.gfx.setup(.{
        .environment = sk.glue.environment(),
        .logger = .{ .func = sk.log.func },
    });
    runInfo.init();
}

export fn event(evt: ?*const Event) void {
    runInfo.event(evt);
}

export fn frame() void {
    runInfo.frame();
}

export fn cleanup() void {
    sk.gfx.shutdown();
    runInfo.deinit();
}
