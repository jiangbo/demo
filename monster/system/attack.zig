const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");

pub fn update(reg: *zhu.ecs.Registry, _: f32) void {
    var view = reg.view(.{com.Target});

    while (view.next()) |entity| {
        if (view.has(entity, com.AttackTimer)) continue; // 攻击冷却中

        const target = view.get(entity, com.Target).v;
        if (!reg.validEntity(target)) continue; // 目标无效

        // 播放攻击动画
        view.add(entity, com.AnimationPlay{
            .index = @intFromEnum(com.StateEnum.attack),
        });

        // 设置攻击锁定，不能进行移动
        view.add(entity, com.AttackLock{});

        // 设置攻击冷却
        const cool = view.get(entity, com.CoolDown).v;
        view.add(entity, com.AttackTimer{ .v = .init(cool) });
    }
}
