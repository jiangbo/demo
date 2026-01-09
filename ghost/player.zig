const std = @import("std");
const zhu = @import("zhu");

const camera = zhu.camera;
const window = zhu.window;

const maxSpeed = 500;
const idleFrames = zhu.graphics.framesX(8, .init(48, 48), 0.1);
const size = idleFrames[0].area.size.scale(2);

pub var position: zhu.Vector2 = undefined;
var velocity: zhu.Vector2 = .zero;
var animation: zhu.graphics.FrameAnimation = undefined;

pub fn init(initPosition: zhu.Vector2) void {
    const imageId = zhu.graphics.imageId("sprite/ghost-idle.png");
    animation = .init(imageId, &idleFrames);
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

    animation.update(delta);
}

fn move(delta: f32) void {
    position = position.add(velocity.scale(delta));
}

pub fn draw() void {
    const image = animation.currentImage();
    zhu.batch.drawOption(image, position, .{
        .size = size,
    });
}
