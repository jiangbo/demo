const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const audio = zhu.audio;
const math = zhu.math;

const scene = @import("../scene.zig");
const context = @import("../context.zig");
const factory = @import("../factory.zig");
const component = @import("../component.zig");
const storage = @import("../storage.zig");
const zon = @import("../zon.zig");
const shared = @import("shared.zig");

const Story = component.event.Story;

pub var key: zon.Actor.Key = undefined;
pub var actor: zon.Actor = undefined;

// 根据稳定人物标识重置当前敌方数据。
pub fn reset(actorKey: zon.Actor.Key) void {
    key = actorKey;
    actor = zon.Actor.get(key).*;
}

pub const Attack = struct {
    // 开始敌方攻击动画。
    pub fn enter(_: *ecs.World) void {
        audio.playSound(
            shared.attackSounds[shared.enemySounds[actor.picture]],
        );
        shared.bombAnimation.reset();
    }

    // 攻击动画结束后进入玩家受伤阶段。
    pub fn update(_: *ecs.World, delta: f32) ?shared.Phase {
        if (shared.bombAnimation.update(delta) == .end) {
            return .playerHurt;
        }
        return null;
    }

    // 在玩家位置绘制攻击动画。
    pub fn draw(_: *ecs.World) void {
        zhu.batch.drawImage(
            shared.bombAnimation.subImage(),
            .xy(120, 220),
            .{},
        );
    }
};

pub const Hurt = struct {
    var damage: u16 = 0;
    var timer: zhu.Timer = .init(0.5);
    var offset: f32 = 5;

    // 计算敌方受到的伤害并开始受伤动画。
    pub fn enter(world: *ecs.World) void {
        audio.playSound(
            shared.hurtSounds[shared.enemySounds[actor.picture]],
        );

        const stats = world.getGlobal(storage.Stats).?;
        damage = shared.computeDamage(stats.attack, actor.defend);
        actor.health -|= damage;
        timer.restart();
    }

    // 受伤动画结束后判断敌方是否死亡。
    pub fn update(_: *ecs.World, delta: f32) ?shared.Phase {
        if (timer.updateFinished(delta)) {
            if (actor.health == 0) return .enemyDeath;

            shared.Wait.next = .enemyAttack;
            return .wait;
        }

        const period: u8 = @intFromFloat(
            @trunc(timer.elapsed / 0.08),
        );
        offset = if (period % 2 == 0) -5 else 5;
        return null;
    }

    // 绘制敌方抖动和伤害数字。
    pub fn draw(_: *ecs.World) void {
        const position = math.Vector2.xy(465, 237).addX(offset);
        zhu.batch.drawImage(
            factory.npcBattleImage(key),
            position,
            .{},
        );

        var buffer: [10]u8 = undefined;
        const y = std.math.lerp(230, 190, timer.progress());
        const text = zhu.format(&buffer, "-{}", .{damage});
        zhu.text.msdf.begin();
        defer zhu.text.msdf.end();
        zhu.text.draw(text, .xy(465, y), .{});
    }
};

pub const Death = struct {
    var step: u8 = 0;

    // 播放敌方死亡声音并发送剧情进度事件。
    pub fn enter(world: *ecs.World) void {
        audio.playSound(
            shared.deadSounds[shared.enemySounds[actor.picture]],
        );
        step = 0;
        if (actor.progress != 0xFF) {
            world.addEvent(Story{ .progress = actor.progress });
        }
    }

    // 依次结算奖励、升级和战斗结果。
    pub fn update(world: *ecs.World, _: f32) ?shared.Phase {
        const stats = world.getGlobal(storage.Stats).?;
        const inventory = world.getGlobal(storage.Inventory).?;
        if (step == 0 and zon.input.released(.confirm)) {
            step += 1;
            stats.exp += actor.level * 20;
            inventory.money += actor.money;
            for (actor.goods) |itemKey| {
                _ = inventory.add(itemKey);
            }
            return null;
        }

        if (step == 1 and zon.input.released(.confirm)) {
            if (stats.levelUp()) {
                step += 1;
                return null;
            }
        }

        if (zon.input.released(.confirm)) {
            context.battle.result = .win;
            scene.changeScene(.world);
        }
        return null;
    }

    // 绘制胜利、奖励和升级提示。
    pub fn draw(world: *ecs.World) void {
        zhu.text.msdf.begin();
        defer zhu.text.msdf.end();

        zhu.text.draw("胜利了！", .xy(285, 175), .{});
        if (step < 1) return;

        var buffer: [100]u8 = undefined;
        var text = zhu.format(
            &buffer,
            "获得：经验=[{}] 金钱=[{}]",
            .{ actor.level * 20, actor.money },
        );
        zhu.text.draw(text, .xy(220, 210), .{});

        if (actor.goods.len != 0) {
            zhu.text.draw("缴获物品：", .xy(220, 240), .{});

            for (actor.goods) |itemKey| {
                const name = zon.Item.get(itemKey).name;
                zhu.text.draw(
                    name,
                    .xy(310, 240),
                    .{ .color = .yellow },
                );
            }

            std.debug.assert(actor.goods.len == 1);
        }
        if (step == 2) {
            const level = world.getGlobal(storage.Stats).?.level;
            text = zhu.format(
                &buffer,
                "等级升为({})^_^",
                .{level},
            );
            zhu.text.draw(
                text,
                .xy(260, 270),
                .{ .color = .yellow },
            );
        }
    }
};
