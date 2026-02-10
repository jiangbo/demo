const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");

pub fn update(reg: *zhu.ecs.Registry, _: f32) void {
    var view = reg.view(.{ com.attack.Target, com.attack.Ready });

    while (view.next()) |entity| {
        const target = view.get(entity, com.attack.Target).v;
        if (!reg.validEntity(target)) continue; // 目标无效

        // 播放攻击动画
        const ranged = view.has(entity, com.Ranged);
        const attack: com.StateEnum = if (ranged) .ranged else .attack;
        view.add(entity, com.AnimationPlay{
            .index = @intFromEnum(attack),
        });

        // 设置攻击锁定，不能进行移动
        view.add(entity, com.attack.Lock{});

        // 设置攻击冷却
        view.remove(entity, com.attack.Ready);
        reg.addEvent(com.Timer{
            .remaining = view.get(entity, com.CoolDown).v,
            .entity = view.toEntity(entity),
            .type = .attack,
        });
    }
}
