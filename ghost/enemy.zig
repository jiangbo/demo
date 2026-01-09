const std = @import("std");
const zhu = @import("zhu");

const camera = zhu.camera;

const player = @import("player.zig");

pub const Enemy = struct {
    position: zhu.Vector2,
    animation: zhu.graphics.FrameAnimation,
};
const frames = zhu.graphics.framesX(4, .init(32, 32), 0.2);
const size = frames[0].area.size.scale(2);
const maxSpeed = 100;

var enemy: Enemy = undefined;

pub fn init() void {
    const image = zhu.graphics.getImage("sprite/ghost-Sheet.png");
    enemy = Enemy{
        .position = player.position.add(.init(200, 200)),
        .animation = .init(image, &frames),
    };
}

pub fn update(delta: f32) void {
    const dir = player.position.sub(enemy.position);
    const distance = dir.normalize().scale(maxSpeed * delta);
    enemy.position = enemy.position.add(distance);

    enemy.animation.update(delta);
}

pub fn draw() void {
    const image = enemy.animation.currentImage();
    camera.drawImage(image, enemy.position, .{
        .size = size,
    });
}
