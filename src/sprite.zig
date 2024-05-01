const std = @import("std");
const zlm = @import("zlm");
const Texture2D = @import("texture.zig").Texture2D;
// const SpriteRenderer = @import("renderer.zig").SpriteRenderer;

pub const Sprite = struct {
    texture: Texture2D,
    position: zlm.Vec2 = zlm.Vec2.zero,
    size: zlm.Vec2 = zlm.Vec2.new(10, 10),
    rotate: f32 = 0,
    color: zlm.Vec3 = zlm.Vec3.one,
    solid: bool = false,
    destroyed: bool = false,

    pub fn checkCollision(s1: Sprite, s2: Sprite) bool {
        const collisionX = s1.position.x + s1.size.x >= s2.position.x //
        and s2.position.x + s2.size.x >= s1.position.x;

        const collisionY = s1.position.y + s1.size.y >= s2.position.y //
        and s2.position.y + s2.size.y >= s1.position.y;

        return collisionX and collisionY;
    }
};

pub const Ball = struct {
    sprite: Sprite,
    radius: f32,
    stuck: bool = true,
    velocity: zlm.Vec2 = zlm.Vec2.new(100, -350),

    pub fn move(self: *Ball, deltaTime: f32, width: f32) zlm.Vec2 {
        if (self.stuck) return self.sprite.position;

        const delta = self.velocity.scale(deltaTime);
        self.sprite.position = self.sprite.position.add(delta);

        if (self.sprite.position.x <= 0) {
            self.velocity.x = -self.velocity.x;
            self.sprite.position.x = 0;
        }

        if (self.sprite.position.x + self.sprite.size.x >= width) {
            self.velocity.x = -self.velocity.x;
            self.sprite.position.x = width - self.sprite.size.x;
        }

        if (self.sprite.position.y <= 0) {
            self.velocity.y = -self.velocity.y;
            self.sprite.position.y = 0;
        }

        return self.sprite.position;
    }

    pub fn checkCollision(self: Ball, s2: Sprite) bool {
        const center = self.sprite.position.add(zlm.Vec2.all(self.radius));

        const aabbHalf = s2.size.scale(0.5);
        const aabbCenter = s2.position.add(aabbHalf);

        var difference = center.sub(aabbCenter);
        const clamped = difference.componentClamp(aabbHalf.neg(), aabbHalf);
        const closest = aabbCenter.add(clamped);
        difference = closest.sub(center);
        return difference.length() < self.radius;
    }
};
