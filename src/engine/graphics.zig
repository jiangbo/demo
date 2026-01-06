const std = @import("std");

const gpu = @import("gpu.zig");
const batch = @import("batch.zig");
const math = @import("math.zig");
const assets = @import("assets.zig");
const window = @import("window.zig");

pub const Texture = gpu.Texture;
pub const frameStats = gpu.frameStats;
pub const queryFrameStats = gpu.queryFrameStats;
pub const queryBackend = gpu.queryBackend;

pub const Color = math.Vector4;
pub const Image = batch.Image;
pub const Vertex = batch.QuadVertex;
pub const draw = batch.draw;
pub const beginDraw = batch.beginDraw;
pub const endDraw = batch.endDraw;
pub const Option = batch.Option;
pub const imageDrawCount = batch.imageDrawCount;

pub const loadAtlas = assets.loadAtlas;
pub const loadImage = assets.loadImage;
pub const imageId = assets.id;
pub const ImageId = assets.Id;
pub const getImage = assets.getImage;

pub const Frame = struct { area: math.Rect, interval: f32 = 0.1 };

pub const FrameAnimation = struct {
    elapsed: f32 = 0,
    index: u8 = 0,
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
        _ = self.isFinishedAfterUpdate(delta);
    }

    pub fn isFinishedAfterUpdate(self: *FrameAnimation, delta: f32) bool {
        if (self.finished()) return true;

        self.elapsed += delta;
        if (self.elapsed < self.frames[self.index].interval) return false;

        self.elapsed -= self.frames[self.index].interval;
        self.index += 1;
        if (self.loop and self.index == self.frames.len) self.index = 0;

        return !self.loop and self.index == self.frames.len;
    }

    pub fn stop(self: *FrameAnimation) void {
        self.index = @intCast(self.frames.len);
        self.loop = false;
    }

    pub fn finished(self: *const FrameAnimation) bool {
        return !self.loop and self.index == self.frames.len;
    }

    pub fn reset(self: *FrameAnimation) void {
        self.index = 0;
        self.elapsed = 0;
    }
};

pub const Atlas = struct {
    imagePath: [:0]const u8,
    size: math.Vector2,
    images: []const struct { id: ImageId, area: math.Rect },
};

pub fn rgb(r: f32, g: f32, b: f32) math.Vector4 {
    return color(r, g, b, 1);
}
pub const rgba = color;
pub fn color(r: f32, g: f32, b: f32, a: f32) math.Vector4 {
    return .{ .x = r, .y = g, .z = b, .w = a };
}

pub fn init(size: math.Vector2, buffer: []Vertex) void {
    batch.init(size, buffer);
}

pub var whiteImage: ImageId = undefined;
pub fn initWithWhiteTexture(size: math.Vector2, buffer: []Vertex) void {
    init(size, buffer);
    whiteImage = assets.createWhiteImage("engine/white");
}

pub fn scissor(area: math.Rect) void {
    const min = area.min.mul(window.ratio);
    const size = area.size.mul(window.ratio);
    batch.encodeCommand(.{ .scissor = .{ .min = min, .size = size } });
}
pub fn resetScissor() void {
    batch.encodeCommand(.{ .scissor = .fromMax(.zero, window.clientSize) });
}

pub fn encodeScaleCommand(scale: math.Vector2) void {
    batch.setScale(scale);
    batch.startNewDrawCommand();
}
