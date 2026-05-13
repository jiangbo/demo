const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");

pub fn update(reg: *zhu.ecs.Registry, delta: f32) void {
    _ = delta;

    var view = reg.view(.{com.animation.Finished});

    while (view.next()) |entity| {
        if (reg.has(entity, com.DeadOnFinish)) {
            reg.add(entity, com.Dead{});
            continue;
        }

        var state = com.StateEnum.idle;
        if (reg.has(entity, com.Player)) {
            if (reg.tryGet(entity, com.skill.Skill)) |skill| {
                if (skill.id == .shield and reg.has(entity, com.skill.Active)) {
                    state = .walk;
                }
            }
        }
        // 敌人需要区分是否被阻挡
        var blocked = false;
        if (reg.tryGet(entity, com.motion.BlockBy)) |blockBy| {
            if (reg.validEntity(blockBy.v)) blocked = true else {
                reg.remove(entity, com.motion.BlockBy);
            }
        }
        if (reg.has(entity, com.Enemy) and !blocked) state = .walk;

        reg.add(entity, com.animation.Play{
            .index = @intFromEnum(state),
            .loop = true,
        });

        // 移除攻击锁定
        reg.remove(entity, com.attack.Lock);
    }

    reg.clear(com.animation.Finished);
}
