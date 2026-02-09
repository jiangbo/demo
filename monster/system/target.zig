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
    var view = reg.reverseView(.{ com.attack.Range, com.Target });

    while (view.next()) |entity| {
        const target = view.get(entity, com.Target).v;
        if (reg.validEntity(target)) { // 目标还存活
            const range = view.get(entity, com.attack.Range).v + 20; // 目标的中心
            const pos = view.get(entity, com.Position);
            const targetPos = reg.get(target, com.Position);
            if (pos.sub(targetPos).length2() <= range * range) {
                continue; // 目标在攻击范围内
            }
        }
        std.log.debug("entity: {} clean target: {}", .{ entity, target });
        view.remove(entity, com.Target);
    }
}

///
/// 选择一个最近的攻击目标
///
const attack = com.attack;
pub fn selectAttackTarget(reg: *zhu.ecs.Registry) void {
    var view = reg.view(.{ com.Position, attack.Range, attack.Ready });
    while (view.next()) |entity| {
        if (view.has(entity, com.Target)) continue; // 已经有目标了

        const pos = view.get(entity, com.Position);
        const range = view.get(entity, com.attack.Range).v + 20; // 目标的中心
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
            view.add(entity, com.Target{ .v = view.toEntity(target) });
            std.log.debug("entity: {} attack: {}", .{ entity, target });
        }
    }
}
