const std = @import("std");
const zhu = @import("zhu");

const camera = zhu.camera;
const window = zhu.window;

const battle = @import("battle.zig");

const circle = zhu.graphics.imageId("circle.png"); // 显示碰撞范围
const maxSpeed = 500;
const frames = zhu.graphics.framesX(8, .xy(48, 48), 0.1);
const deadFrames = zhu.graphics.framesX(17, .xy(64, 64), 0.1);
pub const size = frames[0].area.size;
const Status = enum { idle, move };

var idleImage: zhu.graphics.Image = undefined;
var moveImage: zhu.graphics.Image = undefined;

pub var position: zhu.Vector2 = undefined;
pub var stats: battle.Stats = .{};
var mana: u32 = 100;

var hurtTimer: window.Timer = .init(1.5); // 无敌时间
var velocity: zhu.Vector2 = .zero;
var velocityTimer: window.Timer = .init(0.03);
var animation: zhu.graphics.FrameAnimation = undefined;
var deadAnimation: zhu.graphics.FrameAnimation = undefined;
var status: Status = .idle;

pub fn init(initPosition: zhu.Vector2) void {
    idleImage = zhu.graphics.getImage("sprite/ghost-idle.png");
    moveImage = zhu.graphics.getImage("sprite/ghost-move.png");

    const deadImage = zhu.graphics.getImage("effect/1764.png");
    deadAnimation = .init(deadImage, &deadFrames);

    animation = .init(idleImage, &frames);
    position = initPosition;
}

var manaTimer: window.Timer = .init(1); // 每秒回复一次魔法值
pub fn update(delta: f32, worldSize: zhu.Vector2) void {
    if (stats.health == 0) {
        // 角色已死亡
        return deadAnimation.onceUpdate(delta);
    }
    hurtTimer.update(delta);

    if (velocityTimer.isFinishedLoopUpdate(delta)) {
        // 速度衰减不应该和帧率相关
        velocity = velocity.scale(0.9);
    }

    if (manaTimer.isFinishedLoopUpdate(delta)) {
        mana += 10;
        if (mana > 100) mana = 100;
    }

    if (window.isKeyPress(.A)) velocity = .xy(-maxSpeed, 0);
    if (window.isKeyPress(.D)) velocity = .xy(maxSpeed, 0);
    if (window.isKeyPress(.W)) velocity = .xy(0, -maxSpeed);
    if (window.isKeyPress(.S)) velocity = .xy(0, maxSpeed);

    // 角色使用魔法
    if (window.isMouseDown(.LEFT) and mana > 30) {
        const spellPos = camera.toWorld(window.mousePosition);
        const cast = battle.playerCastSpell(spellPos);
        if (cast) mana -= 30;
    }

    move(delta);
    position.clamp(.zero, worldSize.sub(size));
    animation.loopUpdate(delta);
}

pub fn hurt(damage: u32) void {
    if (hurtTimer.isRunning()) return; // 受伤后的无敌时间

    stats.health -|= damage; // 扣除生命值
    hurtTimer.elapsed = 0; // 重置计时器
}

fn move(delta: f32) void {
    position = position.add(velocity.scale(delta));

    const new: Status = if (velocity.length2() < 0.01) .idle else .move;
    if (new == status) return; // 状态未变化
    status = new;
    animation.image = if (new == .move) moveImage else idleImage;
}

pub fn draw() void {
    if (stats.health == 0) {
        if (!deadAnimation.isRunning()) return; // 动画结束不需要显示

        const image = deadAnimation.currentImage();
        return camera.drawImage(image, position, .{
            .size = size.scale(2), // 和角色的显示区域一样大
            .anchor = .center,
        });
    }

    camera.drawImage(animation.currentImage(), position, .{
        .size = size.scale(2),
        .flipX = velocity.x < 0,
        .anchor = .center,
    });

    // debug 显示碰撞范围
    camera.drawOption(circle, position, .{
        .color = .{ .y = 1, .w = 0.4 },
        .size = size,
        .anchor = .center,
    });
}

const backImage = zhu.graphics.imageId("UI/bar_bg.png");
const healthBarImage = zhu.graphics.imageId("UI/bar_red.png");
const healthImage = zhu.graphics.imageId("UI/Red Potion.png");
const manaBarImage = zhu.graphics.imageId("UI/bar_blue.png");
const manaImage = zhu.graphics.imageId("UI/Blue Potion.png");
pub fn drawStats() void {

    // 生命值
    var pos: zhu.Vector2 = .xy(30, 30);
    var option: camera.Option = .{
        .scale = .xy(3, 3),
        .anchor = .xy(0, 0.5),
    };

    camera.drawOption(backImage, pos.addX(30), option);
    var percent = zhu.math.percentInt(stats.health, stats.maxHealth);
    option.scale.x = option.scale.x * percent;
    camera.drawOption(healthBarImage, pos.addX(30), option);
    option.scale = .xy(0.5, 0.5);
    camera.drawOption(healthImage, pos, option);

    // 法力值
    pos = .xy(300, 30);
    option = .{ .scale = .xy(3, 3), .anchor = .xy(0, 0.5) };

    camera.drawOption(backImage, pos.addX(30), option);
    percent = zhu.math.percentInt(mana, 100);
    option.scale.x = option.scale.x * percent;
    camera.drawOption(manaBarImage, pos.addX(30), option);
    option.scale = .xy(0.5, 0.5);
    camera.drawOption(manaImage, pos, option);
}
