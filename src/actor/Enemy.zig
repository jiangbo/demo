const std = @import("std");

const gfx = @import("../graphics.zig");
const math = @import("../math.zig");
const window = @import("../window.zig");
const SharedActor = @import("actor.zig").SharedActor;

const Enemy = @This();

shared: SharedActor,

idleAnimation: gfx.SliceFrameAnimation,

pub fn init() Enemy {
    var enemy: Enemy = .{
        .shared = .{
            .position = .{ .x = 1000, .y = SharedActor.FLOOR_Y },
            .faceLeft = true,
        },
        .idleAnimation = .load("assets/enemy/idle/{}.png", 5),
    };

    enemy.idleAnimation.loop = true;
    return enemy;
}

pub fn update(self: *Enemy, delta: f32) void {
    self.shared.update(delta);
    self.idleAnimation.update(delta);
}

pub fn render(self: *const Enemy) void {
    self.shared.render();
    self.play(&self.idleAnimation);
}

fn play(self: *const Enemy, animation: *const gfx.SliceFrameAnimation) void {
    gfx.playSliceFlipX(animation, self.shared.position, !self.shared.faceLeft);
}
