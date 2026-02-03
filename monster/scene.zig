const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;

const map = @import("map.zig");
const com = @import("component.zig");

var registry: ecs.Registry = undefined;
var timer: zhu.Timer = .init(2);

pub fn init() void {
    registry = .init(zhu.assets.allocator);
    map.init();
}

fn spawnEnemy() void {
    var image = zhu.assets.loadImage("assets/textures/Enemy/wolf.png", .xy(5760, 768));
    image = image.sub(.init(.zero, .xy(192, 192)));

    for (map.startPaths) |startId| {
        if (startId == 0) break;

        const start = map.paths.get(startId).?;
        const enemy = registry.createEntity();
        registry.add(enemy, start.point);
        registry.add(enemy, com.Velocity{ .v = .zero });
        registry.add(enemy, com.Enemy{ .target = start, .speed = 40 });

        registry.add(enemy, com.Sprite{
            .image = image,
            .offset = .xy(-96, -128),
            .flip = false,
        });
    }
}

pub fn deinit() void {
    map.deinit();
    registry.deinit();
}

pub fn update(delta: f32) void {
    if (timer.isFinishedLoopUpdate(delta)) spawnEnemy();

    map.update(delta);

    followPath();

    var view = registry.view(.{ com.Position, com.Velocity });
    while (view.next()) |entity| {
        const position = view.getPtr(entity, com.Position);
        const velocity = view.get(entity, com.Velocity);
        position.* = position.*.add(velocity.v.scale(delta));
    }

    // 处理到达终点的敌人
    for (registry.getEvents(ecs.Entity)) |entity| {
        registry.destroyEntity(entity);
    }
    registry.clearEvent(ecs.Entity);
}

pub fn followPath() void {
    var view = registry.view(.{ com.Position, com.Enemy });
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
    }
}

pub fn draw() void {
    map.draw();

    var view = registry.view(.{ com.Sprite, com.Position, com.Velocity });
    while (view.next()) |entity| {
        const sprite = view.get(entity, com.Sprite);
        const position = view.get(entity, com.Position);
        const velocity = view.get(entity, com.Velocity);
        const pos = position.add(sprite.offset);
        zhu.batch.drawImage(sprite.image, pos, .{
            .flipX = (velocity.v.x < 0) == sprite.flip,
        });
    }

    for (map.startPaths) |start| {
        if (start == 0) break;

        var prev = map.paths.get(start).?;
        while (prev.next != 0) {
            const next = map.paths.get(prev.next).?;
            zhu.batch.drawLine(prev.point, next.point, .{
                .color = .red,
                .width = 4,
            });
            prev = next;
        }
    }
}
