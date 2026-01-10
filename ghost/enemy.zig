const std = @import("std");
const zhu = @import("zhu");

const camera = zhu.camera;

const player = @import("player.zig");

const State = enum { normal, hurt, dead };
const Enemy = struct {
    position: zhu.Vector2,
    animation: zhu.graphics.FrameAnimation,
};
const normalFrames = zhu.graphics.framesX(4, .init(32, 32), 0.2);
const deadFrames = zhu.graphics.framesX(8, .init(32, 32), 0.1);
const size = deadFrames[0].area.size.scale(2);
const maxSpeed = 100;
const circle = zhu.graphics.imageId("circle.png"); // 显示碰撞范围

var animations: zhu.graphics.EnumFrameAnimation(State) = undefined;
var enemy: Enemy = undefined;

pub fn init() void {
    var image = zhu.graphics.getImage("sprite/ghost-Sheet.png");
    animations.set(.normal, .init(image, &normalFrames));
    image = zhu.graphics.getImage("sprite/ghostHurt-Sheet.png");
    animations.set(.hurt, .init(image, &normalFrames)); // 受伤和普通动画一样
    image = zhu.graphics.getImage("sprite/ghostDead-Sheet.png");
    animations.set(.dead, .init(image, &deadFrames));

    // 暂时将动画设置为不重复播放，看看动画切换的效果
    for (&animations.values, 0..) |*animation, i| {
        animation.loop = false;
        animation.state = @intCast(i);
    }

    enemy = Enemy{
        .position = player.position.add(.init(200, 200)),
        .animation = animations.get(.normal),
    };
}

pub fn update(delta: f32) void {
    // 怪物先不移动，方便看碰撞。
    // const dir = player.position.sub(enemy.position);
    // const distance = dir.normalize().scale(maxSpeed * delta);
    // enemy.position = enemy.position.add(distance);

    if (enemy.animation.isFinishedAfterUpdate(delta)) {
        const next = zhu.nextEnum(State, enemy.animation.state);
        enemy.animation = animations.get(next);
    }

    const len = (player.size.x + size.x) * 0.5;
    const len2 = player.position.sub(enemy.position).length2();
    collided = len2 < len * len;
}
var collided: bool = false;

pub fn draw() void {
    const image = enemy.animation.currentImage();
    var option: camera.Option = .{ .size = size, .anchor = .center };
    camera.drawImage(image, enemy.position, option);

    option.color = .{ .y = 1, .w = 0.4 };
    if (collided) option.color = .{ .x = 1, .w = 0.4 };

    camera.drawOption(circle, enemy.position, option);
}
