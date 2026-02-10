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
            const msg = "实体: {} 治疗目标: {}, 生命值: {}";
            std.log.debug(msg, .{ entity, target.index, stats.health });
            continue;
        }

        // 伤害
        const damage = attack - stats.defense;
        stats.health -= @max(damage, @divTrunc(attack, 10));
        const msg = "实体: {} 攻击目标: {}, 伤害: {}, 生命值: {}";
        std.log.debug(msg, .{ entity, target.index, damage, stats.health });

        view.add(target.index, com.attack.Injured{}); // 目标受伤了
        if (stats.health <= 0) {
            view.add(target.index, com.Dead{}); // 目标死了
        }
    }

    reg.clear(com.attack.Hit);
}

const percentInt = zhu.math.percentInt;
pub fn draw(reg: *zhu.ecs.Registry) void {
    const size: zhu.Vector2 = .xy(40, 10);

    var view = reg.view(.{ com.attack.Injured, com.Stats });
    while (view.next()) |entity| {
        const stats = view.getPtr(entity, com.Stats);
        const percent = percentInt(stats.health, stats.maxHealth);

        var pos = view.get(entity, com.Position);
        pos = pos.addXY(-size.x / 2, size.y);

        var color = zhu.graphics.Color.red;
        if (percent > 0.7) color = .green //
        else if (percent > 0.3) color = .yellow;

        var rect = zhu.math.Rect{ .min = pos, .size = size };
        zhu.batch.drawRectBorder(rect, 2, color);
        rect.size.x *= @max(percent, 0);
        zhu.batch.drawRect(rect, .{ .color = color });
    }
}
