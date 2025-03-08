const std = @import("std");
const cache = @import("cache.zig");
const gpu = @import("gpu.zig");

pub const Texture = gpu.Texture;

pub const Camera = struct {
    const zm = @import("zmath");

    proj: zm.Mat,

    pub fn init(width: f32, height: f32) Camera {
        const proj = zm.orthographicOffCenterLh(0, width, 0, height, 0, 1);
        return .{ .proj = proj };
    }

    pub fn vp(self: Camera) zm.Mat {
        return self.proj;
    }
};

pub var camera: Camera = undefined;
pub var renderer: gpu.Renderer = undefined;
var passEncoder: gpu.RenderPassEncoder = undefined;

pub fn init(width: f32, height: f32) void {
    camera = Camera.init(width, height);
    renderer = gpu.Renderer.init();
}

pub fn loadTexture(path: [:0]const u8) ?Texture {
    return cache.TextureCache.load(path);
}

pub fn beginDraw() void {
    passEncoder = gpu.CommandEncoder.beginRenderPass(.{ .r = 1, .b = 1, .a = 1.0 });
    renderer.renderPass = passEncoder;
}

pub fn draw(x: f32, y: f32, tex: Texture) void {
    renderer.draw(.{
        .uniform = .{ .vp = camera.vp() },
        .x = x,
        .y = y,
        .texture = tex,
    });
}

pub fn drawFlipX(x: f32, y: f32, tex: Texture, flipX: bool) void {
    renderer.draw(.{
        .uniform = .{ .vp = camera.vp() },
        .x = x,
        .y = y,
        .texture = tex,
        .flipX = flipX,
    });
}

pub fn endDraw() void {
    passEncoder.submit();
}

pub fn BoundedTextureAtlas(max: u8) type {
    return struct {
        textures: [max]Texture,

        pub fn init(comptime pathFmt: []const u8) @This() {
            var self = @This(){ .textures = undefined };
            var buffer: [128]u8 = undefined;
            for (0..max) |index| {
                const path = std.fmt.bufPrintZ(&buffer, pathFmt, .{index + 1});

                const texture = cache.TextureCache.load(path catch unreachable);
                self.textures[index] = texture.?;
            }

            return self;
        }
    };
}
