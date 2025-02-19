const std = @import("std");
const zm = @import("zmath");
const sk = @import("sokol");

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

pub const Color = sk.gfx.Color;
pub const Buffer = sk.gfx.Buffer;

pub const BindGroup = struct {
    value: sk.gfx.Bindings = .{},

    pub fn bindImage(self: *BindGroup, width: u32, height: u32, data: []u8) void {
        self.value.images[shd.IMG_tex] = sk.gfx.allocImage();

        sk.gfx.initImage(self.value.images[shd.IMG_tex], .{
            .width = @as(i32, @intCast(width)),
            .height = @as(i32, @intCast(height)),
            .pixel_format = .RGBA8,
            .data = init: {
                var image = sk.gfx.ImageData{};
                image.subimage[0][0] = sk.gfx.asRange(data);
                break :init image;
            },
        });

        self.value.samplers[shd.SMP_smp] = sk.gfx.makeSampler(.{
            .min_filter = .LINEAR,
            .mag_filter = .LINEAR,
        });
    }

    pub fn bindStorageBuffer(self: *BindGroup, index: u32, storageBuffer: anytype) void {
        self.value.storage_buffers[index] = sk.gfx.makeBuffer(.{
            .type = .STORAGEBUFFER,
            .data = sk.gfx.asRange(storageBuffer),
        });
    }

    pub fn updateStorageBuffer(self: *BindGroup, index: u32, storageBuffer: anytype) void {
        sk.gfx.destroyBuffer(self.value.storage_buffers[index]);
        self.value.storage_buffers[index] = sk.gfx.makeBuffer(.{
            .type = .STORAGEBUFFER,
            .data = sk.gfx.asRange(storageBuffer),
        });
    }
};

pub const CommandEncoder = struct {
    pub fn beginRenderPass(self: *CommandEncoder, color: Color) RenderPass {
        _ = self;
        var action = sk.gfx.PassAction{};
        action.colors[0] = .{ .clear_value = color };
        sk.gfx.beginPass(.{ .action = action, .swapchain = sk.glue.swapchain() });
        return RenderPass{};
    }

    pub fn finish(self: *CommandEncoder) void {
        _ = self;
        sk.gfx.commit();
    }
};

pub const RenderPass = struct {
    pub fn setPipeline(self: *RenderPass, pipeline: RenderPipeline) void {
        _ = self;
        sk.gfx.applyPipeline(pipeline.value);
    }

    pub fn setBindGroup(self: *RenderPass, index: u32, group: BindGroup) void {
        _ = self;
        _ = index;
        sk.gfx.applyBindings(group.value);
    }

    pub fn draw(self: *RenderPass, number: u32) void {
        _ = self;
        sk.gfx.draw(0, number, 1);
    }

    pub fn end(self: *RenderPass) void {
        _ = self;
        sk.gfx.endPass();
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
