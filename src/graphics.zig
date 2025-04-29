const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const animation = @import("animation.zig");

pub const Texture = gpu.Texture;

pub const Camera = struct {
    rect: math.Rectangle,
    border: math.Vector,

    pub fn lookAt(self: *Camera, pos: math.Vector) void {
        const half = self.rect.size().scale(0.5);

        const max = self.border.sub(self.rect.size());
        const offset = pos.sub(half).clamp(.zero, max);

        self.rect = .init(offset, self.rect.size());
    }
};

pub var renderer: gpu.Renderer = undefined;
var matrix: [16]f32 = undefined;
var passEncoder: gpu.RenderPassEncoder = undefined;
pub var camera: Camera = .{ .rect = .{}, .border = .zero };

pub fn init(size: math.Vector) void {
    matrix = .{
        2 / size.x, 0.0,         0.0, 0.0,
        0.0,        2 / -size.y, 0.0, 0.0,
        0.0,        0.0,         1,   0.0,
        -1,         1,           0,   1.0,
    };
    renderer = gpu.Renderer.init();
}

pub const deinit = gpu.deinit;

pub fn beginDraw() void {
    passEncoder = gpu.CommandEncoder.beginRenderPass(
        .{ .r = 1, .b = 1, .a = 1.0 },
        &matrix,
    );

    renderer.renderPass = passEncoder;
}

pub fn drawRectangle(rect: math.Rectangle) void {
    gpu.drawRectangleLine(rect);
}

pub fn draw(tex: Texture, position: math.Vector) void {
    drawFlipX(tex, position, false);
}

pub fn drawFlipX(tex: Texture, pos: math.Vector, flipX: bool) void {
    const target: math.Rectangle = .init(pos, tex.size());
    var src = tex.area;
    if (flipX) {
        src.min.x = tex.area.max.x;
        src.max.x = tex.area.min.x;
    }

    drawOptions(tex, .{ .sourceRect = src, .targetRect = target });
}

pub const DrawOptions = struct {
    sourceRect: math.Rectangle = .{},
    targetRect: math.Rectangle = .{},
    angle: f32 = 0,
    pivot: math.Vector = .zero,
    alpha: f32 = 1,
};

pub fn drawOptions(texture: Texture, options: DrawOptions) void {
    matrix[12] = -1 - camera.rect.min.x * matrix[0];
    matrix[13] = 1 - camera.rect.min.y * matrix[5];

    var src = options.sourceRect;
    if (src.min.approx(.zero) and src.max.approx(.zero)) {
        src = texture.area;
    }

    renderer.draw(.{
        .uniform = .{ .vp = matrix },
        .texture = texture,
        .sourceRect = src,
        .targetRect = options.targetRect,
        .radians = std.math.degreesToRadians(options.angle),
        .pivot = options.pivot,
        .alpha = options.alpha,
    });
}

pub fn endDraw() void {
    passEncoder.submit();
}

pub const FrameAnimation = animation.FrameAnimation;
pub const FixedFrameAnimation = animation.FixedFrameAnimation;
