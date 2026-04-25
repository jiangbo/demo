const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");
const spawn = @import("../spawn.zig");
const ctx = @import("../context.zig");

/// 处理死亡实体
pub fn update(reg: *zhu.ecs.Registry, _: f32) void {
    var deadView = reg.reverseView(.{com.Dead});
    while (deadView.next()) |entity| {
        std.log.info("处理死亡实体：{}", .{entity});

        if (!deadView.has(entity, com.Enemy)) {
            reg.destroyEntity(deadView.toEntity(entity));
            continue;
        }
        ctx.enemyKilledCount += 1;

        if (deadView.tryGet(entity, com.motion.BlockBy)) |blockBy| {
            // 死亡实体被阻挡了，释放阻挡锁定
            if (reg.tryGetPtr(blockBy.v, com.motion.Blocker)) |blocker| {
                blocker.current -|= 1;
            }
        }

        reg.removeExcept(deadView.toEntity(entity), .{
            com.Position,
            com.Animation,
            com.Sprite,
        });
        deadView.add(entity, com.Ghost{});
        deadView.add(entity, com.animation.Play{
            .index = @intFromEnum(com.StateEnum.damage),
        });
    }
}
