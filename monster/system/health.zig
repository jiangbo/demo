const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");

pub fn update(reg: *zhu.ecs.Registry, _: f32) void {
    var view = reg.view(.{ com.attack.Hit, com.attack.Target });
    while (view.next()) |entity| {
        const target = view.get(entity, com.attack.Target).v;
        if (!reg.validEntity(target)) continue; // 目标已经死了

        const attack = view.getPtr(entity, com.Stats).attack;
        const stats = view.getPtr(target.index, com.Stats);

        if (attack < 0) { // 治疗
            stats.health -= attack;
            if (stats.health >= stats.maxHealth) {
                stats.health = stats.maxHealth;
                reg.remove(target, com.attack.Injured); // 移除受伤标签
            }
            const msg = "entity: {} heal target: {}, health: {}";
            std.log.debug(msg, .{ entity, target, stats.health });
            continue;
        }

        // 伤害
        const damage = @max(attack - stats.defense, 10);
        stats.health -= damage;
        const msg = "entity: {} hit target: {}, damage: {}, health: {}";
        std.log.debug(msg, .{ entity, target, damage, stats.health });

        view.add(target.index, com.attack.Injured{}); // 目标受伤了
        if (stats.health <= 0) {
            view.add(target.index, com.Dead{}); // 目标死了
        }
    }

    reg.clear(com.attack.Hit);
}
