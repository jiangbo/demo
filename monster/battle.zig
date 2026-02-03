const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;
const com = @import("component.zig");

///
/// 验证攻击目标是否死亡，是否在攻击范围内。
///
pub fn cleanInvalidTarget(reg: *ecs.Registry) void {
    var view = reg.viewOption(.{ com.AttackRange, com.Target }, .{
        .reverse = true, // 倒序遍历，因为遍历 Target 的时候可能会移除它
    });

    while (view.next()) |entity| {
        const target = view.get(entity, com.Target).v;
        if (reg.validEntity(target)) { // 目标还存活
            const range = view.get(entity, com.AttackRange).v + 20; // 目标的中心
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
/// 给无目标的实体选择一个攻击目标。
///
pub fn selectTarget(reg: *ecs.Registry) void {
    selectTargetForPlayer(reg);
    selectTargetForEnemy(reg);
}

fn selectTargetForPlayer(reg: *ecs.Registry) void {
    var view = reg.view(.{ com.Player, com.Position, com.AttackRange });
    while (view.next()) |player| {
        if (view.has(player, com.Target)) continue; // 已经有目标了

        const pos = view.get(player, com.Position);
        const range = view.get(player, com.AttackRange).v + 20; // 目标的中心
        const range2 = range * range;

        var enemyView = reg.view(.{ com.Enemy, com.Position });
        var closestEnemy: ?zhu.ecs.Entity.Index = null;
        var closestLength2: f32 = std.math.floatMax(f32);

        while (enemyView.next()) |enemy| {
            const enemyPos = enemyView.get(enemy, com.Position);
            const length2 = pos.sub(enemyPos).length2();
            if (length2 <= range2 and length2 < closestLength2) {
                closestEnemy = enemy;
                closestLength2 = length2;
            }
        }
        if (closestEnemy) |enemy| {
            view.add(player, com.Target{ .v = view.toEntity(enemy) });
            std.log.debug("player: {} select enemy: {}", .{ player, enemy });
        }
    }
}

fn selectTargetForEnemy(reg: *ecs.Registry) void {
    var view = reg.view(.{ com.Enemy, com.Position, com.AttackRange });
    while (view.next()) |enemy| {
        if (view.has(enemy, com.Target)) continue; // 已经有目标了

        const pos = view.get(enemy, com.Position);
        const range = view.get(enemy, com.AttackRange).v + 20; // 目标的中心
        const range2 = range * range;

        var playerView = reg.view(.{ com.Player, com.Position });
        var closestPlayer: ?zhu.ecs.Entity.Index = null;
        var closestLength2: f32 = std.math.floatMax(f32);

        while (playerView.next()) |player| {
            const playerPos = playerView.get(player, com.Position);
            const length2 = pos.sub(playerPos).length2();
            if (length2 <= range2 and length2 < closestLength2) {
                closestPlayer = player;
                closestLength2 = length2;
            }
        }
        if (closestPlayer) |player| {
            view.add(enemy, com.Target{ .v = view.toEntity(player) });
            std.log.debug("enemy: {} select player: {}", .{ enemy, player });
        }
    }
}
