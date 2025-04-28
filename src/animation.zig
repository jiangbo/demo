const std = @import("std");

const window = @import("window.zig");
const cache = @import("cache.zig");
const math = @import("math.zig");
const Texture = @import("gpu.zig").Texture;

pub const FrameAnimation = struct {
    timer: window.Timer = .init(0.1),
    index: usize = 0,
    loop: bool = true,
    texture: Texture,
    frames: []const math.Rectangle,
    offset: math.Vector = .zero,

    pub fn init(name: []const u8, texture: Texture, count: u8) FrameAnimation {
        const frames = cache.RectangleSlice.load(name, count);

        const width = @divExact(texture.width(), @as(f32, @floatFromInt(count)));
        const size: math.Vector = .{ .x = width, .y = texture.height() };

        for (0..frames.len) |index| {
            const x = @as(f32, @floatFromInt(index)) * width;
            frames[index] = .init(.init(x, texture.area.min.y), size);
        }

        return .{ .texture = texture, .frames = frames };
    }

    pub fn current(self: *const FrameAnimation) Texture {
        return self.texture.map(self.frames[self.index]);
    }

    pub fn update(self: *FrameAnimation, delta: f32) void {
        if (self.timer.isRunningAfterUpdate(delta)) return;

        if (self.index == self.frames.len - 1) {
            if (self.loop) self.reset();
        } else {
            self.timer.reset();
            self.index += 1;
        }
    }

    pub fn anchor(self: *FrameAnimation, direction: math.EightDirection) void {
        const tex = self.texture;
        self.offset = switch (direction) {
            .down => .{ .x = -tex.width() / 2, .y = -tex.height() },
            else => unreachable,
        };
    }

    pub fn anchorCenter(self: *FrameAnimation) void {
        self.offset.x = -self.texture.width() / 2;
        self.offset.y = -self.texture.height() / 2;
    }

    pub fn reset(self: *FrameAnimation) void {
        self.timer.reset();
        self.index = 0;
    }

    pub fn finished(self: *const FrameAnimation) bool {
        return self.timer.finished and !self.loop;
    }
};
