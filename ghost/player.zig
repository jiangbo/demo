const std = @import("std");
const zhu = @import("zhu");

const camera = zhu.camera;
const window = zhu.window;
const graphics = zhu.graphics;

const maxSpeed = 500;

pub var position: zhu.Vector2 = undefined;
const size: zhu.Vector2 = .square(20);
var velocity: zhu.Vector2 = .zero;
const image = graphics.imageId("sprite/ghost-idle.png");

pub fn init(initPosition: zhu.Vector2) void {
    position = initPosition;
}

pub fn update(delta: f32, worldSize: zhu.Vector2) void {
    velocity = velocity.scale(0.9);
    if (window.isKeyPress(.A)) velocity = .init(-maxSpeed, 0);
    if (window.isKeyPress(.D)) velocity = .init(maxSpeed, 0);
    if (window.isKeyPress(.W)) velocity = .init(0, -maxSpeed);
    if (window.isKeyPress(.S)) velocity = .init(0, maxSpeed);

    move(delta);
    position.clamp(.zero, worldSize.sub(size));
}

fn move(delta: f32) void {
    position = position.add(velocity.scale(delta));
}

pub fn draw() void {
    camera.drawRectBorder(.init(position, size), 5, .red);
    camera.draw(image, position);
}
