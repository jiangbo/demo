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
    solid: bool = true,
    destroyed: bool = false,
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
};
