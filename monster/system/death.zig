const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");
const spawn = @import("../spawn.zig");

/// 处理死亡实体
pub fn update(reg: *zhu.ecs.Registry, _: f32) void {
    var ghostView = reg.view(.{com.Ghost});
    while (ghostView.next()) |entity| {
        std.log.info("处理幽灵实体：{}", .{entity});

        if (ghostView.tryGet(entity, com.motion.BlockBy)) |blockBy| {
            // 死亡实体被阻挡了，释放阻挡锁定
            if (reg.tryGetPtr(blockBy.v, com.motion.Blocker)) |blocker| {
                blocker.current -|= 1;
            }
        }

        reg.removeExcept(ghostView.toEntity(entity), .{
            com.Ghost,
            com.Position,
            com.Animation,
            com.Sprite,
        });
        ghostView.add(entity, com.animation.Play{
            .index = @intFromEnum(com.StateEnum.damage),
        });
    }

    var deadView = reg.reverseView(.{com.Dead});
    while (deadView.next()) |entity| {
        std.log.info("删除死亡实体：{}", .{entity});
        reg.destroyEntity(deadView.toEntity(entity));
    }
}
