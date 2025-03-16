const std = @import("std");
const window = @import("../window.zig");
const gfx = @import("../graphics.zig");

const scene = @import("../scene.zig");

pub const Vector = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    pub fn add(a: Vector, b: Vector) Vector {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn scale(a: Vector, b: f32) Vector {
        return .{ .x = a.x * b, .y = a.y * b, .z = a.z * b };
    }
};

pub const BulletType = enum { pea, sun };

pub const Bullet = struct {
    size: Vector,
    position: Vector,
    velocity: Vector,
    damage: f32,
    dead: bool = false,
    collide: bool = false,
    p1: bool = true,

    type: BulletType = .pea,
    animationBreak: gfx.FrameAnimation,

    texture: gfx.Texture = undefined,

    pub fn render(self: *Bullet) void {
        if (self.collide) {
            self.animationBreak.play(self.position.x, self.position.y);
        } else {
            gfx.draw(self.position.x, self.position.y, self.texture);
        }
    }
};
