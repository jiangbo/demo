const std = @import("std");

const cache = @import("cache.zig");
const gpu = @import("gpu.zig");
const animation = @import("animation.zig");

pub const Texture = gpu.Texture;

pub var renderer: gpu.Renderer = undefined;
var matrix: [16]f32 = undefined;
var passEncoder: gpu.RenderPassEncoder = undefined;

pub fn init(width: f32, height: f32) void {
    matrix = .{
        2 / width, 0.0,         0.0, 0.0,
        0.0,       2 / -height, 0.0, 0.0,
        0.0,       0.0,         1,   0.0,
        -1,        1,           0,   1.0,
    };
    renderer = gpu.Renderer.init();
}

pub fn loadTexture(path: [:0]const u8) Texture {
    return cache.TextureCache.load(path);
}

pub fn beginDraw() void {
    passEncoder = gpu.CommandEncoder.beginRenderPass(.{ .r = 1, .b = 1, .a = 1.0 });
    renderer.renderPass = passEncoder;
}

pub fn draw(tex: Texture, x: f32, y: f32) void {
    drawFlipX(tex, x, y, false);
}

pub fn drawFlipX(tex: Texture, x: f32, y: f32, flipX: bool) void {
    const target: gpu.Rectangle = .{ .x = x, .y = y };
    const src = gpu.Rectangle{
        .w = if (flipX) -tex.width() else tex.width(),
    };

    drawOptions(tex, .{ .sourceRect = src, .targetRect = target });
}

pub const DrawOptions = struct {
    sourceRect: ?gpu.Rectangle = null,
    targetRect: gpu.Rectangle,
};

pub fn drawOptions(texture: Texture, options: DrawOptions) void {
    renderer.draw(.{
        .uniform = .{ .vp = matrix },
        .texture = texture,
        .sourceRect = options.sourceRect,
        .targetRect = options.targetRect,
    });
}

pub fn endDraw() void {
    passEncoder.submit();
}

pub const FrameAnimation = animation.FrameAnimation;

pub fn play(frameAnimation: *const FrameAnimation, x: f32, y: f32) void {
    playFlipX(frameAnimation, x, y, false);
}

pub fn playFlipX(frame: *const FrameAnimation, x: f32, y: f32, flipX: bool) void {
    drawFlipX(frame.textures[frame.index], x, y, flipX);
}
