const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");

pub fn update(reg: *zhu.ecs.Registry, _: f32) void {
    cleanInvalidTarget(reg);
    selectAttackTarget(reg);
}

///
/// 验证攻击目标是否死亡，是否在攻击范围内。
///
pub fn cleanInvalidTarget(reg: *zhu.ecs.Registry) void {
    var view = reg.reverseView(.{ attack.Range, attack.Target });

    while (view.next()) |entity| {
        if (view.has(entity, attack.Lock)) continue; // 攻击锁定时不能切换目标

        const target = view.get(entity, attack.Target).v;
        if (reg.validEntity(target)) { // 目标还存活
            const range = view.get(entity, attack.Range).v + 20; // 目标的中心
            const pos = view.get(entity, com.Position);
            const targetPos = reg.get(target, com.Position);
            if (pos.sub(targetPos).length2() <= range * range) {
                continue; // 目标在攻击范围内
            }
        }
        std.log.debug("实体: {} 清除目标: {}", .{ entity, target.index });
        view.remove(entity, attack.Target);
    }
}

///
/// 选择一个最近的攻击目标
///
const attack = com.attack;
pub fn selectAttackTarget(reg: *zhu.ecs.Registry) void {
    var view = reg.view(.{ attack.Range, attack.Ready });
    while (view.next()) |entity| {
        if (view.has(entity, attack.Healer)) {
            selectHealTarget(reg, view.toEntity(entity)); // 选择治疗目标
            continue;
        }
        if (view.has(entity, attack.Target)) continue; // 已经有目标了

        const pos = view.get(entity, com.Position);
        const range = view.get(entity, attack.Range).v + 20; // 目标的中心
        const range2 = range * range;

        var closestTarget: ?zhu.ecs.Entity.Index = null; // 找最近的敌方
        var closestLength2: f32 = std.math.floatMax(f32);

        const isEnemy = view.has(entity, com.Enemy);
        var targetView = reg.view(.{com.Position});
        while (targetView.next()) |target| {
            if (isEnemy == view.has(target, com.Enemy)) continue; // 同一边的

            const targetPos = targetView.get(target, com.Position);
            const length2 = pos.sub(targetPos).length2();
            if (length2 <= range2 and length2 < closestLength2) {
                closestTarget = target;
                closestLength2 = length2;
            }
        }

        if (closestTarget) |target| {
            view.add(entity, attack.Target{ .v = view.toEntity(target) });
            std.log.debug("实体: {} 选择攻击目标: {}", .{ entity, target });
        }
    }
}

fn selectHealTarget(reg: *zhu.ecs.Registry, entity: zhu.ecs.Entity) void {
    // 寻找自身范围内，血量最低的友方单位。
    const pos = reg.get(entity, com.Position);
    const range = reg.get(entity, attack.Range).v + 20; // 目标的中心
    const range2 = range * range;

    var lowestTarget: ?zhu.ecs.Entity.Index = null; // 找血量最低的友方
    var lowestHealth: i32 = std.math.maxInt(i32);

    var view = reg.view(.{ com.Player, com.attack.Injured }); // 找受伤的玩家
    while (view.next()) |target| {
        const targetPos = view.get(target, com.Position);
        if (pos.sub(targetPos).length2() > range2) continue; // 不在治疗范围内

        const health = view.get(target, com.Stats).health;
        if (health > lowestHealth) continue;

        lowestHealth = health;
        lowestTarget = target;
    }

    if (lowestTarget) |target| {
        reg.add(entity, attack.Target{ .v = view.toEntity(target) });
        std.log.debug("实体: {} 选择治疗目标: {}", .{ entity.index, target });
    } else {
        reg.remove(entity, attack.Target); // 移除之前的目标
    }
}
