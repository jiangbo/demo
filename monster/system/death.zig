const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");
const spawn = @import("../spawn.zig");
const ctx = @import("../context.zig");

/// 处理死亡实体
pub fn update(reg: *zhu.ecs.Registry, _: f32) void {
    var deadView = reg.reverseView(.{com.Dead});
    while (deadView.next()) |entity| {
        std.log.info("death entity: {}", .{entity});
        defer reg.destroy(entity);

        if (reg.has(entity, com.Player)) {
            spawn.releasePlace(deadView.toEntity(entity));
            continue;
        }

        // 死亡实体被阻挡了，释放阻挡锁定
        if (reg.tryGet(entity, com.motion.BlockBy)) |blockBy| {
            if (reg.toIndex(blockBy.v)) |blocker_index| {
                const blocker = reg.tryGetPtr(blocker_index, com.motion.Blocker) orelse continue;
                blocker.current -|= 1;
            }
        }

        if (reg.has(entity, com.EnemyEnum)) {
            ctx.enemyKilledCount += 1;
            const enemyEntity = deadView.toEntity(entity);
            spawn.deadEnemy(reg, enemyEntity);
        }
    }
}
