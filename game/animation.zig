const std = @import("std");
const gfx = @import("graphics.zig");
const cache = @import("cache.zig");

pub const FrameAnimation = struct {
    interval: f32,
    frames: [maxFrame]gfx.Texture = undefined,
    count: u32,
    current: u32 = 0,
    timer: f32 = 0,

    const maxFrame = 10;

    pub fn load(comptime pathFmt: []const u8, count: u32, interval: f32) ?FrameAnimation {
        if (count <= 0 or count > maxFrame) {
            std.log.warn("frame count must be (0, {}], actual: {}", .{ maxFrame, count });
            return null;
        }

        var self = FrameAnimation{ .interval = interval, .count = count };

        var buffer: [64]u8 = undefined;
        for (0..count) |index| {
            const path = std.fmt.bufPrintZ(&buffer, pathFmt, .{index}) catch |e| {
                std.log.warn("frame animation path error: {}", .{e});
                return null;
            };

            const texture = cache.TextureCache.load(path);
            self.frames[index] = texture orelse return null;
        }

        return self;
    }

    pub fn play(self: *FrameAnimation, delta: f32) void {
        self.timer += delta;
        if (self.timer >= self.interval) {
            self.current = (self.current + 1) % self.count;
            self.timer = 0;
        }
    }

    pub fn currentTexture(self: FrameAnimation) gfx.Texture {
        return self.frames[self.current];
    }
};
