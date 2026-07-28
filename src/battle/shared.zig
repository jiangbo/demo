const zhu = @import("zhu");
const ecs = @import("ecs");

const zon = @import("../zon.zig");

pub const attackSounds: [3][:0]const u8 = .{
    "voc/ack_00.ogg",
    "voc/ack_01.ogg",
    "voc/ack_02.ogg",
};

pub const hurtSounds: [3][:0]const u8 = .{
    "voc/ao_00.ogg",
    "voc/ao_01.ogg",
    "voc/ao_02.ogg",
};

pub const deadSounds: [3][:0]const u8 = .{
    "voc/dead_00.ogg",
    "voc/dead_01.ogg",
    "voc/dead_02.ogg",
};

pub const enemySounds: [15]u8 = .{
    2, 1, 2, 2, 1,
    2, 1, 1, 2, 1,
    1, 1, 1, 1, 2,
};

// 双方阶段通过该标识返回下一阶段。
pub const Phase = enum {
    menu,
    playerAttack,
    enemyHurt,
    wait,
    enemyAttack,
    playerHurt,
    playerDeath,
    enemyDeath,
    status,
    item,
    win,
    escape,
    title,
};

// 当前敌人的稳定标识和可变数据副本。
pub var enemyKey: zon.Actor.Key = undefined;
pub var enemy: zon.Actor = undefined;

pub var bombAnimation: zhu.Animation = undefined;

// 根据攻击和防御计算本次伤害。
pub fn computeDamage(attack: u16, defend: u16) u16 {
    var damage = attack * 2 -| defend;

    if (damage <= 10) {
        damage = zhu.random.intBiased(u16, 0, 10);
    } else {
        damage += zhu.random.intBiased(u16, 0, damage);
    }
    return damage;
}

pub const Wait = struct {
    pub var timer: zhu.Timer = .init(0.5);
    pub var next: Phase = .menu;
    pub var tip: []const u8 = &.{};

    // 重新开始阶段等待。
    pub fn enter(_: *ecs.World) void {
        timer.restart();
    }

    // 等待结束后返回预先设置的阶段。
    pub fn update(_: *ecs.World, delta: f32) ?Phase {
        if (!timer.updateFinished(delta)) return null;

        tip = &.{};
        return next;
    }

    // 绘制等待期间的临时提示。
    pub fn draw(_: *ecs.World) void {
        if (tip.len == 0) return;

        zhu.text.msdf.begin();
        defer zhu.text.msdf.end();
        zhu.text.draw(tip, .xy(290, 210), .{});
    }
};
