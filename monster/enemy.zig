const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;

const com = @import("component.zig");
const map = @import("map.zig");
const Animation = zhu.graphics.Animation;

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

            const ani: Animation = .init(image, value.animations[0]);
            registry.add(enemy, ani);
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
