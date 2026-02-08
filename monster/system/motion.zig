const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");
const map = @import("../map.zig");

pub fn update(reg: *zhu.ecs.Registry, delta: f32) void {
    followPath(reg);
    move(reg, delta);
}

fn followPath(registry: *zhu.ecs.Registry) void {
    var view = registry.view(.{ com.Position, com.Enemy, com.Velocity });
    while (view.next()) |entity| {
        if (view.has(entity, com.BlockBy)) continue; // 被阻挡的不处理
        if (view.has(entity, com.AttackLock)) continue; // 攻击锁定的不处理

        // 当前位置和目标位置是否足够靠近
        const enemy = view.getPtr(entity, com.Enemy);
        const pos = view.get(entity, com.Position);
        if (enemy.target.point.sub(pos).length2() > 25) continue;

        // 到达目标位置，转向，即更新速度
        const nextPathId = enemy.target.randomNext();
        if (nextPathId == 0) { // 到达终点，销毁实体
            registry.addEvent(view.toEntity(entity));
            continue;
        }
        enemy.target = map.paths.get(nextPathId).?;
        const velocity = view.getPtr(entity, com.Velocity);
        const direction = enemy.target.point.sub(pos).normalize();
        velocity.v = direction.scale(enemy.speed);
        const face: com.Face = if (direction.x < 0) .left else .right;
        view.add(entity, face);
    }
}

fn move(registry: *zhu.ecs.Registry, delta: f32) void {
    var view = registry.view(.{ com.Position, com.Velocity });
    while (view.next()) |entity| {
        if (view.has(entity, com.BlockBy)) continue; // 被阻挡的不处理
        if (view.has(entity, com.AttackLock)) continue; // 攻击锁定的不处理

        // 先移动
        const position = view.getPtr(entity, com.Position);
        const velocity = view.get(entity, com.Velocity);
        position.* = position.*.add(velocity.v.scale(delta));

        // 再检查是否被阻挡
        var blockView = registry.view(.{ com.Position, com.Blocker });
        while (blockView.next()) |blocker| {
            const pos = blockView.get(blocker, com.Position);
            if (pos.sub(position.*).length2() > 40 * 40) continue;

            const block = blockView.getPtr(blocker, com.Blocker);
            if (block.current < block.max) {
                view.remove(entity, com.Velocity);
                const ent = blockView.toEntity(blocker);
                view.add(entity, com.BlockBy{ .v = ent });
                block.current += 1;
                break;
            }
        }
    }
}
