const std = @import("std");
const zhu = @import("zhu");

const camera = zhu.camera;
const window = zhu.window;

const circle = zhu.graphics.imageId("circle.png"); // 显示碰撞范围
const maxSpeed = 500;
const frames = zhu.graphics.framesX(8, .init(48, 48), 0.1);
pub const size = frames[0].area.size;
const Status = enum { idle, move };

var idleImage: zhu.graphics.Image = undefined;
var moveImage: zhu.graphics.Image = undefined;

pub var position: zhu.Vector2 = undefined;
var velocity: zhu.Vector2 = .zero;
var animation: zhu.graphics.FrameAnimation = undefined;
var status: Status = .idle;

pub fn init(initPosition: zhu.Vector2) void {
    idleImage = zhu.graphics.getImage("sprite/ghost-idle.png");
    moveImage = zhu.graphics.getImage("sprite/ghost-move.png");

    animation = .init(idleImage, &frames);
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

    const new: Status = if (velocity.length2() < 0.01) .idle else .move;
    if (new == status) return; // 状态未变化
    status = new;
    animation.image = if (new == .move) moveImage else idleImage;
}

pub fn draw() void {
    camera.drawImage(animation.currentImage(), position, .{
        .size = size.scale(2),
        .flipX = velocity.x < 0,
        .anchor = .center,
    });
    camera.drawOption(circle, position, .{
        .color = .{ .y = 1, .w = 0.4 },
        .size = size,
        .anchor = .center,
    });
}
