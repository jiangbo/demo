const std = @import("std");
const zhu = @import("zhu");

const moveForce = 200; // 移动力
const factor = 0.85; // 减速因子
const maxSpeed = 120; // 最大速度
const size: zhu.Vector2 = .xy(32, 32);
var image: zhu.graphics.Image = undefined;

var velocity: zhu.Vector2 = .zero;
var position: zhu.Vector2 = undefined;

pub fn init(pos: zhu.Vector2) void {
    position = pos;
    const foxy = zhu.getImage("textures/Actors/foxy.png");
    image = foxy.sub(.init(.zero, size));
}

pub fn update(delta: f32) void {
    if (zhu.window.isKeyDown(.A)) {
        if (velocity.x > 0) velocity.x = 0;
        velocity.x -= moveForce * delta;
    } else if (zhu.window.isKeyDown(.D)) {
        if (velocity.x < 0) velocity.x = 0;
        velocity.x += moveForce * delta;
    } else {
        // 没有按的时候，减少速度
        velocity.x *= factor;
    }

    velocity.x = std.math.clamp(velocity.x, -maxSpeed, maxSpeed);
    position = position.add(velocity.scale(delta));
}

pub fn draw() void {
    zhu.batch.drawImage(image, position, .{
        .flipX = velocity.x < 0,
    });
}
