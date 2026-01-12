const std = @import("std");
const zhu = @import("zhu");

const camera = zhu.camera;

const player = @import("player.zig");
const enemy = @import("enemy.zig");

pub const Stats = struct {
    health: u32 = 100, // 生命值
    maxHealth: u32 = 100, // 最大生命值
    attack: u32 = 40, // 攻击力
};

const circle = zhu.graphics.imageId("circle.png"); // 显示碰撞范围
const spellFrames = zhu.graphics.framesX(13, .xy(64, 64), 0.1);
const spellDamageIndex = 6; // 动画第 6 帧造成伤害，视觉效果好一点
const spellSize = spellFrames[0].area.size.scale(3);

var spellTimer: zhu.window.Timer = .init(2);
var spellAnimations: [4]zhu.graphics.FrameAnimation = undefined;
var spellPositions: [4]zhu.Vector2 = undefined;
var mana: u32 = 100;
var manaTimer: zhu.window.Timer = .init(1); // 每秒回复一次魔法值

pub fn init() void {
    const image = zhu.graphics.getImage("effect/Thunderstrike w blur.png");
    for (&spellAnimations) |*a| a.* = .initFinished(image, &spellFrames);
}

pub fn update(delta: f32) void {
    spellTimer.update(delta);
    if (manaTimer.isFinishedLoopUpdate(delta)) {
        mana += 10;
        if (mana > 100) mana = 100;
    }

    for (&spellPositions, &spellAnimations) |pos, *ani| {
        if (ani.isFinished()) continue;

        const changed = ani.isNextOnceUpdate(delta);
        if (changed and ani.index == spellDamageIndex) {
            var iterator = std.mem.reverseIterator(enemy.enemies.items);
            while (iterator.nextPtr()) |e| {
                const len = (spellSize.x + enemy.size.x) * 0.5;
                const len2 = pos.sub(e.position).length2();
                if (len2 < len * len) e.stats.health -|= player.stats.attack;
                if (e.stats.health == 0) {
                    _ = enemy.enemies.swapRemove(iterator.index);
                }
            }
        }
    }
}

pub fn playerCastSpell(position: zhu.Vector2) void {
    if (mana < 30 or spellTimer.isRunning()) return;

    for (&spellPositions, &spellAnimations) |*pos, *ani| {
        if (ani.isFinished()) {
            pos.* = position;
            ani.reset();
            mana -= 30;
            return;
        }
    }
}

pub fn draw() void {
    for (&spellPositions, &spellAnimations) |pos, ani| {
        if (ani.isFinished()) continue;

        const image = ani.currentImage();
        camera.drawImage(image, pos, .{
            .anchor = .center,
            .size = spellSize,
        });

        camera.drawOption(circle, pos, .{
            .anchor = .center,
            .size = spellSize,
            .color = .{ .y = 1, .w = 0.4 },
        });
    }
}

const backImage = zhu.graphics.imageId("UI/bar_bg.png");
const healthBarImage = zhu.graphics.imageId("UI/bar_red.png");
const healthImage = zhu.graphics.imageId("UI/Red Potion.png");
const manaBarImage = zhu.graphics.imageId("UI/bar_blue.png");
const manaImage = zhu.graphics.imageId("UI/Blue Potion.png");
pub fn drawUI() void {

    // 生命值
    var pos: zhu.Vector2 = .xy(30, 30);
    var option: camera.Option = .{
        .scale = .xy(3, 3),
        .anchor = .xy(0, 0.5),
    };

    const stats = player.stats;
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

    // 冷却时间
}
