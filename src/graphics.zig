const std = @import("std");
// const cache = @import("cache.zig");
const gpu = @import("gpu.zig");
const window = @import("window.zig");

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

// pub fn loadTexture(path: [:0]const u8) ?Texture {
//     return cache.TextureCache.load(path);
// }

// pub fn loadTextures(textures: []Texture, comptime pathFmt: []const u8, from: u8) void {
//     std.log.info("loading texture slice : {s}", .{pathFmt});

//     var buffer: [128]u8 = undefined;
//     for (from..from + textures.len) |index| {
//         const path = std.fmt.bufPrintZ(&buffer, pathFmt, .{index});

//         const texture = loadTexture(path catch unreachable);
//         textures[index - from] = texture.?;
//     }
// }

pub fn beginDraw() void {
    passEncoder = gpu.CommandEncoder.beginRenderPass(.{ .r = 1, .b = 1, .a = 1.0 });
    renderer.renderPass = passEncoder;
}

pub fn draw(x: f32, y: f32, tex: Texture) void {
    drawFlipX(x, y, tex, false);
}

pub fn drawFlipX(x: f32, y: f32, tex: Texture, flipX: bool) void {
    const target: gpu.Rectangle = .{ .x = x, .y = y };
    const src = gpu.Rectangle{
        .w = if (flipX) -tex.width else tex.width,
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
