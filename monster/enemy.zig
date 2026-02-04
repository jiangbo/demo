const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;

const com = @import("component.zig");
const map = @import("map.zig");
const Animation = zhu.graphics.MultiAnimation;

const Enemy = struct {
    enemyEnum: enum { slime, wolf, goblin, darkWitch },
    name: []const u8,
    health: u32,
    attack: u32,
    defense: u32,
    range: f32,
    interval: f32,
    speed: f32,
    ranged: bool,
    faceRight: bool,
    size: zhu.Vector2,
    offset: zhu.Vector2,
    image: struct { path: [:0]const u8, size: zhu.Vector2 },
    animations: []const []const zhu.graphics.Frame = &.{},
};

const zon: []const Enemy = @import("zon/enemy.zon");

pub fn spawn(registry: *ecs.Registry) void {
    for (map.startPaths) |startId| {
        if (startId == 0) break;

        const start = map.paths.get(startId).?;
        for (zon) |value| {
            const enemy = registry.createEntity();
            registry.add(enemy, start.point);
            registry.add(enemy, com.Velocity{ .v = .zero });
            registry.add(enemy, com.Enemy{
                .target = start,
                .speed = value.speed,
            });

            const path = value.image.path;
            const image = zhu.assets.loadImage(path, value.image.size);
            registry.add(enemy, com.Sprite{
                .image = image.sub(.init(.zero, value.size)),
                .offset = value.offset,
                .flip = value.faceRight,
            });

            var animation: Animation = .init(image, value.animations);
            animation.change(@intFromEnum(com.StateEnum.walk));
            registry.add(enemy, animation);

            // 添加攻击范围组件
            registry.add(enemy, com.AttackRange{ .v = value.range });
        }
    }
}

pub fn followPath(registry: *ecs.Registry) void {
    var view = registry.view(.{ com.Position, com.Enemy, com.Velocity });
    while (view.next()) |entity| {
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
        const face: com.Face = if (direction.x < 0) .Left else .Right;
        view.add(entity, face);
    }
}

pub fn move(registry: *ecs.Registry, delta: f32) void {
    var view = registry.view(.{ com.Position, com.Velocity });
    while (view.next()) |entity| {
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

pub fn attack(registry: *ecs.Registry, delta: f32) void {
    var view = registry.view(.{ com.Position, com.Enemy, com.AttackTimer });
    while (view.next()) |entity| {
        const enemy = view.getPtr(entity, com.Enemy);
        const pos = view.get(entity, com.Position);
        enemy.target.point; // 目标位置

        var attackTimer = view.getPtr(entity, com.AttackTimer);
        attackTimer.time += delta;
        if (attackTimer.time < enemy.interval) continue;

        if (pos.sub(enemy.target.point).length2() <= enemy.range * enemy.range) {
            // 发起攻击
            attackTimer.time = 0;
        }
    }
}
