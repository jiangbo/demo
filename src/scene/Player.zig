const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");

const Player = @This();
const FrameAnimation = gfx.FixedFrameAnimation(4, 0.15);

index: u8,
upAnimation: FrameAnimation,
downAnimation: FrameAnimation,
leftAnimation: FrameAnimation,
rightAnimation: FrameAnimation,

pub fn init(path: [:0]const u8, index: u8) Player {
    const role = window.loadTexture(path, .init(960, 960));
    const size: gfx.Vector = .init(960, 240);

    return Player{
        .index = index,
        .upAnimation = .init(role.subTexture(.init(.{ .y = 720 }, size))),
        .downAnimation = .init(role.subTexture(.init(.{ .y = 0 }, size))),
        .leftAnimation = .init(role.subTexture(.init(.{ .y = 240 }, size))),
        .rightAnimation = .init(role.subTexture(.init(.{ .y = 480 }, size))),
    };
}

pub fn current(self: *Player, face: gfx.FourDirection) *FrameAnimation {
    return switch (face) {
        .up => &self.upAnimation,
        .down => &self.downAnimation,
        .left => &self.leftAnimation,
        .right => &self.rightAnimation,
    };
}
