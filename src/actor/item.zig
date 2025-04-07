const std = @import("std");

const gfx = @import("../graphics.zig");
const math = @import("../math.zig");
const window = @import("../window.zig");
const scene = @import("../scene.zig");

pub const Sword = struct {
    const SPEED_MOVE = 1250;

    position: math.Vector,
    moveLeft: bool,
    valid: bool = true,
    animation: gfx.SliceFrameAnimation,

    pub fn init(pos: math.Vector, moveLeft: bool) Sword {
        var self: Sword = .{
            .position = pos,
            .moveLeft = moveLeft,
            .animation = .load("assets/enemy/sword/{}.png", 3),
        };

        self.animation.anchor = .centerCenter;
        return self;
    }

    pub fn update(self: *Sword, delta: f32) void {
        self.animation.update(delta);

        const direction: f32 = if (self.moveLeft) -1 else 1;
        self.position.x += direction * SPEED_MOVE * delta;

        if (self.position.x < -200 or self.position.x > window.width + 200) {
            self.valid = false;
        }
    }

    pub fn render(self: *const Sword) void {
        gfx.playSliceFlipX(&self.animation, self.position, self.moveLeft);
    }
};
