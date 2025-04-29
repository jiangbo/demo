const std = @import("std");

const window = @import("window.zig");
const math = @import("math.zig");
const Texture = @import("gpu.zig").Texture;

pub const FrameAnimation = FixedFrameAnimation(4, 0.1);

pub fn FixedFrameAnimation(count: u8, time: f32) type {
    return struct {
        timer: window.Timer = .init(time),
        index: usize = 0,
        loop: bool = true,
        texture: Texture,
        frames: [count]math.Rectangle,
        offset: math.Vector = .zero,

        const Animation = @This();

        pub fn init(texture: Texture) Animation {
            var frames: [count]math.Rectangle = undefined;

            const width = @divExact(texture.width(), count);
            const size: math.Vector = .{ .x = width, .y = texture.height() };

            for (0..frames.len) |index| {
                const x = @as(f32, @floatFromInt(index)) * width;
                frames[index] = .init(.init(x, texture.area.min.y), size);
            }

            return .{ .texture = texture, .frames = frames };
        }

        pub fn currentTexture(self: *const Animation) Texture {
            return self.texture.mapTexture(self.frames[self.index]);
        }

        pub fn update(self: *Animation, delta: f32) void {
            if (self.timer.isRunningAfterUpdate(delta)) return;

            if (self.index == self.frames.len - 1) {
                if (self.loop) self.reset();
            } else {
                self.timer.reset();
                self.index += 1;
            }
        }

        pub fn anchor(self: *Animation, direction: math.EightDirection) void {
            const tex = self.texture;
            self.offset = switch (direction) {
                .down => .{ .x = -tex.width() / 2, .y = -tex.height() },
                else => unreachable,
            };
        }

        pub fn anchorCenter(self: *Animation) void {
            self.offset.x = -self.texture.width() / 2;
            self.offset.y = -self.texture.height() / 2;
        }

        pub fn reset(self: *Animation) void {
            self.timer.reset();
            self.index = 0;
        }

        pub fn finished(self: *const Animation) bool {
            return self.timer.finished and !self.loop;
        }
    };
}
