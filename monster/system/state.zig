const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");

pub fn update(reg: *zhu.ecs.Registry, delta: f32) void {
    _ = delta;

    // 动画播放结束，切换动画，需要根据角色和敌人来区分
    var view = reg.view(.{com.animation.Finished});
    defer reg.clear(com.animation.Finished);

    while (view.next()) |entity| {
        var state = com.StateEnum.idle;
        // 敌人需要区分是否被阻挡
        const blocked = view.has(entity, com.motion.BlockBy);
        if (view.has(entity, com.Enemy) and !blocked) state = .walk;

        view.add(entity, com.animation.Play{
            .index = @intFromEnum(state),
            .loop = true,
        });

        // 移除攻击锁定
        view.remove(entity, com.attack.Lock);
    }
}
