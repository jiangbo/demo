const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const assets = @import("assets.zig");
const window = @import("window.zig");

pub const frameStats = gpu.frameStats;
pub const queryFrameStats = gpu.queryFrameStats;
pub const queryBackend = gpu.queryBackend;

pub const Vector2 = math.Vector2;

pub const ImageId = assets.Id;

pub const Frame = struct { offset: Vector2, duration: f32 = 0.1 };
pub const Clip = []const Frame;
pub fn EnumAnimation(comptime T: type) type {
    return std.EnumArray(T, Animation);
}
pub const Animation = struct {
    elapsed: f32 = 0,
    clips: []const Clip,
    clipIndex: u8 = 0,

    index: u8 = 0,
    image: Image,
    extend: u8 = 0,

    pub fn initOne(image: Image, clip: *const Clip) Animation {
        return .{ .image = image, .clips = clip[0..1] };
    }

    pub fn init(image: Image, clips: []const Clip) Animation {
        return .{ .image = image, .clips = clips };
    }

    pub fn initFinished(image: Image, clips: []const Clip) Animation {
        const idx: u8 = @intCast(clips[0].len + 1);
        return .{ .image = image, .clips = clips, .index = idx };
    }

    pub fn play(self: *Animation, clipIndex: u8) void {
        self.clipIndex = clipIndex;
        self.reset();
    }

    pub fn subImage(self: *const Animation, size: Vector2) Image {
        const frame = self.clips[self.clipIndex][self.index];
        return self.image.sub(.init(frame.offset, size));
    }

    pub fn onceUpdate(self: *Animation, delta: f32) void {
        _ = self.isNextOnceUpdate(delta);
    }

    pub fn isNextOnceUpdate(self: *Animation, delta: f32) bool {
        const frames = self.clips[self.clipIndex];
        if (self.index > frames.len) return false; // 已停止

        if (self.index < frames.len) {
            self.elapsed += delta;
            const current = frames[self.index]; // 当前帧
            if (self.elapsed < current.duration) return false;
            self.elapsed -= current.duration;
        }
        self.index += 1;
        return true;
    }

    pub fn isFinishedOnceUpdate(self: *Animation, delta: f32) bool {
        self.onceUpdate(delta);
        return self.index >= self.frames.len;
    }

    pub fn loopUpdate(self: *Animation, delta: f32) void {
        _ = self.isNextLoopUpdate(delta);
    }

    pub fn isNextLoopUpdate(self: *Animation, delta: f32) bool {
        self.elapsed += delta;

        const clip = self.clips[self.clipIndex];
        if (self.elapsed < clip[self.index].duration) return false;
        self.elapsed -= clip[self.index].duration;
        self.index += 1;
        // 结束了从头开始
        if (self.index >= clip.len) self.index = 0;
        return true;
    }

    pub fn getEnumExtend(self: *const Animation, T: type) T {
        return @enumFromInt(self.extend);
    }

    pub fn stop(self: *Animation) void {
        self.index = @intCast(self.frames.len + 1);
    }

    pub fn isRunning(self: *const Animation) bool {
        return self.index < self.clips[self.clipIndex].len;
    }

    pub fn isFinished(self: *const Animation) bool {
        return self.index >= self.clips[self.clipIndex].len;
    }

    pub fn isJustFinished(self: *const Animation) bool {
        return self.index == self.clips[self.clipIndex].len;
    }

    pub fn reset(self: *Animation) void {
        self.index = 0;
        self.elapsed = 0;
    }
};

pub fn framesX(comptime count: u8, size: Vector2, d: f32) [count]Frame {
    var result: [count]Frame = undefined;
    for (&result, 0..) |*frame, i| {
        const index: f32 = @floatFromInt(i);
        frame.area = .init(.xy(index * size.x, 0), size);
        frame.interval = d;
    }
    return result;
}

pub fn loopFramesX(comptime count: u8, size: Vector2, d: f32) //
[count + count - 2]Frame {
    var result: [count + count - 2]Frame = undefined;
    for (&result, 0..) |*frame, i| {
        var index: f32 = @floatFromInt(i);
        if (i >= count) index = @floatFromInt(count + count - 2 - i);
        frame.area = .init(.xy(index * size.x, 0), size);
        frame.interval = d;
    }
    return result;
}

pub const Image = struct {
    texture: gpu.Texture,
    offset: math.Vector2 = .zero,
    size: math.Vector2,

    pub fn sub(self: *const Image, rect: math.Rect) Image {
        return Image{
            .texture = self.texture,
            .offset = self.offset.add(rect.min),
            .size = rect.size,
        };
    }

    pub fn toTexturePosition(self: Image) math.Vector4 {
        return .initSize(self.offset, self.size);
    }
};

pub const Atlas = struct {
    imagePath: [:0]const u8,
    size: math.Vector2,
    images: []const struct { id: ImageId, rect: math.Rect },
};

pub var textCount: u32 = 0;
pub fn beginDraw(clearColor: Color) void {
    gpu.begin(@bitCast(clearColor), window.viewRect);
    textCount = 0;
}

pub const Color = extern struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub const black = Color.rgb(0, 0, 0); // 黑色
    pub const white = Color.rgb(1, 1, 1); // 白色
    pub const midGray = Color.rgb(0.5, 0.5, 0.5); // 中灰色

    pub const red = Color.rgb(1, 0, 0); // 红色
    pub const green = Color.rgb(0, 1, 0); // 绿色
    pub const blue = Color.rgb(0, 0, 1); // 蓝色

    pub const yellow = Color.rgb(1, 1, 0); // 黄色
    pub const cyan = Color.rgb(0, 1, 1); // 青色
    pub const magenta = Color.rgb(1, 0, 1); // 品红色
    pub fn rgb(r: f32, g: f32, b: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = 1 };
    }

    pub fn rgba(r: f32, g: f32, b: f32, a: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn gray(v: f32, a: f32) Color {
        return .{ .r = v, .g = v, .b = v, .a = a };
    }
};

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
