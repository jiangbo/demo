const std = @import("std");
const sk = @import("sokol");

pub const Color = sk.gfx.Color;

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
