const std = @import("std");

const window = @import("window.zig");
const cache = @import("cache.zig");
const math = @import("math.zig");
const Texture = @import("gpu.zig").Texture;

const Anchor = enum {
    topLeft,
    topCenter,
    topRight,
    centerLeft,
    centerCenter,
    centerRight,
    bottomLeft,
    bottomCenter,
    bottomRight,
};

pub const FrameAnimation = SliceFrameAnimation;

const SliceFrameAnimation = struct {
    timer: window.Timer,
    index: usize = 0,
    loop: bool = true,

    textures: []const Frame,

    const Frame = struct {
        texture: Texture,
        area: math.Rectangle,
    };

    pub fn init(textures: []const Texture) SliceFrameAnimation {
        return .{ .textures = textures, .timer = .init(100) };
    }

    pub fn load(comptime pathFmt: []const u8, max: u8) SliceFrameAnimation {
        const textures = cache.TextureSliceCache.load(pathFmt, 1, max);
        return .init(textures);
    }

    pub fn update(self: *@This(), delta: f32) void {
        if (self.timer.isRunningAfterUpdate(delta)) return;

        if (self.index == self.textures.len - 1) {
            if (self.loop) {
                self.index = 0;
                self.timer.reset();
            }
        } else {
            self.timer.reset();
            self.index += 1;
        }
    }

    pub fn reset(self: *@This()) void {
        self.timer.reset();
        self.index = 0;
    }

    pub fn finished(self: *const @This()) bool {
        return self.timer.finished and !self.loop;
    }
};
