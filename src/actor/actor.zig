const std = @import("std");

const gfx = @import("../graphics.zig");
const math = @import("../math.zig");
const window = @import("../window.zig");

pub const Player = @import("Player.zig");
pub const Enemy = @import("Enemy.zig");

pub const SharedActor = struct {
    pub const FLOOR_Y = 620;
    const GRAVITY = 980 * 2;

    enableGravity: bool = true,
    position: math.Vector,
    velocity: math.Vector = .{},
    faceLeft: bool = false,
    health: u8 = 5,

    pub fn update(self: *SharedActor, delta: f32) void {
        if (self.enableGravity) {
            self.velocity.y += GRAVITY * delta;
        }

        self.position = self.position.add(self.velocity.scale(delta));
        if (self.position.y >= FLOOR_Y) {
            self.position.y = FLOOR_Y;
            self.velocity.y = 0;
        }

        self.position.x = std.math.clamp(self.position.x, 0, window.width);
    }

    pub fn render(self: *const SharedActor) void {
        _ = self;
    }
};
