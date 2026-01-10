const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const assets = @import("assets.zig");
const window = @import("window.zig");

pub const Texture = gpu.Texture;
pub const frameStats = gpu.frameStats;
pub const queryFrameStats = gpu.queryFrameStats;
pub const queryBackend = gpu.queryBackend;

pub const Vector2 = math.Vector2;
pub const Color = math.Vector4;

pub const ImageId = assets.Id;
pub const createWhiteImage = assets.createWhiteImage;
pub const loadImage = assets.loadImage;

pub const Frame = struct { area: math.Rect, interval: f32 = 0.1 };

pub fn EnumFrameAnimation(comptime T: type) type {
    return std.EnumArray(T, FrameAnimation);
}
pub const FrameAnimation = struct {
    elapsed: f32 = 0,
    index: u8 = 0,
    loop: bool = true,
    image: Image,
    frames: []const Frame,
    state: u8 = 0,

    pub fn init(image: Image, frames: []const Frame) FrameAnimation {
        return .{ .image = image, .frames = frames };
    }

    pub fn once(image: Image, frames: []const Frame) FrameAnimation {
        return .{ .image = image, .frames = frames, .loop = false };
    }

    pub fn currentImage(self: *const FrameAnimation) Image {
        return self.image.sub(self.frames[self.index].area);
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

pub fn framesX(comptime count: u8, size: Vector2, d: f32) [count]Frame {
    var result: [count]Frame = undefined;
    for (&result, 0..) |*frame, i| {
        const index: f32 = @floatFromInt(i);
        frame.area = .init(.init(index * size.x, 0), size);
        frame.interval = d;
    }
    return result;
}

pub const Image = struct {
    texture: gpu.Texture,
    area: math.Rect,

    pub fn width(self: *const Image) f32 {
        return self.area.size.x;
    }

    pub fn height(self: *const Image) f32 {
        return self.area.size.y;
    }

    pub fn size(self: *const Image) math.Vector2 {
        return self.area.size;
    }

    pub fn sub(self: *const Image, area: math.Rect) Image {
        const moved = area.move(self.area.min);
        return .{ .texture = self.texture, .area = moved };
    }

    pub fn map(self: *const Image, area: math.Rect) Image {
        return .{ .texture = self.texture, .area = area };
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

pub fn imageId(comptime path: []const u8) ImageId {
    return comptime assets.id(path);
}

pub fn getImage(comptime path: []const u8) Image {
    return assets.getImage(imageId(path));
}

pub var textCount: u32 = 0;
pub fn beginDraw(clearColor: math.Vector4) void {
    gpu.begin(clearColor);
    textCount = 0;
}

// pub fn init(size: Vector2, buffer: []Vertex) void {
//     batch.init(size, buffer);
// }

// pub fn scissor(area: math.Rect) void {
//     const min = area.min.mul(window.ratio);
//     const size = area.size.mul(window.ratio);
//     batch.encodeCommand(.{ .scissor = .{ .min = min, .size = size } });
// }
// pub fn resetScissor() void {
//     batch.encodeCommand(.{ .scissor = .fromMax(.zero, window.clientSize) });
// }

// pub fn encodeScaleCommand(scale: Vector2) void {
//     batch.setScale(scale);
//     batch.startNewDrawCommand();
//     要解决开始新的绘制命令后，从哪里获取纹理
// }
