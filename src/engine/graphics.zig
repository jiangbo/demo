const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const assets = @import("assets.zig");
const window = @import("window.zig");

pub const camera = @import("camera.zig");

pub const Texture = gpu.Texture;
pub const Color = math.Vector4;
pub const Vector = math.Vector;
pub const FourDirection = math.FourDirection;
pub const Rectangle = math.Rectangle;
pub const loadTexture = assets.loadTexture;

pub const Frame = struct { area: Rectangle, interval: f32 = 0.1 };

pub const FrameAnimation = struct {
    elapsed: f32 = 0,
    index: usize = 0,
    loop: bool = true,
    texture: Texture,
    frames: []const Frame,

    pub fn init(texture: Texture, frames: []const Frame) FrameAnimation {
        return .{ .texture = texture, .frames = frames };
    }

    pub fn currentTexture(self: *const FrameAnimation) Texture {
        return self.texture.subTexture(self.frames[self.index].area);
    }

    pub fn update(self: *FrameAnimation, delta: f32) void {
        if (self.finished()) return;

        self.elapsed += delta;
        if (self.elapsed < self.frames[self.index].interval) return;

        self.index += 1;
        if (self.index == self.frames.len) {
            if (self.loop) self.reset();
        } else {
            self.elapsed -= self.frames[self.index].interval;
        }
    }

    pub fn reset(self: *FrameAnimation) void {
        self.elapsed = 0;
        self.index = 0;
    }

    pub fn stop(self: *FrameAnimation) void {
        self.index = self.frames.len;
        self.loop = false;
    }

    pub fn finished(self: *const FrameAnimation) bool {
        return !self.loop and self.index == self.frames.len;
    }
};

pub fn color(r: f32, g: f32, b: f32, a: f32) math.Vector4 {
    return .{ .x = r, .y = g, .z = b, .w = a };
}
