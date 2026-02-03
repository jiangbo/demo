const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;

const map = @import("map.zig");
const com = @import("component.zig");
const enemy = @import("enemy.zig");
const player = @import("player.zig");

var registry: ecs.Registry = undefined;
// var timer: zhu.Timer = .init(10);

pub fn init() void {
    registry = .init(zhu.assets.allocator);
    map.init();
    enemy.spawn(&registry);

    player.spawn(&registry, .warrior);
}

pub fn deinit() void {
    map.deinit();
    registry.deinit();
}

pub fn update(delta: f32) void {
    // if (timer.isFinishedLoopUpdate(delta)) enemy.spawn(&registry);

    if (zhu.window.isMousePressed(.LEFT)) {
        player.spawn(&registry, .warrior);
    } else if (zhu.window.isMousePressed(.RIGHT)) {
        player.spawn(&registry, .archer);
    }

    map.update(delta);

    enemy.followPath(&registry);

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

pub fn draw() void {
    map.draw();

    // registry.sort(com.Sprite, struct {
    //     pub fn lessThan(a: com.Sprite, b: com.Sprite) bool {
    //         return a.image.texture.id < b.image.texture.id;
    //     }
    // }.lessThan);

    var view = registry.view(.{ com.Sprite, com.Position });
    while (view.next()) |entity| {
        const sprite = view.get(entity, com.Sprite);
        const position = view.get(entity, com.Position);
        const pos = position.add(sprite.offset);

        const velocity = view.tryGet(entity, com.Velocity);
        var flip = sprite.flip;
        if (velocity) |vel| flip = (vel.v.x < 0) != flip;
        zhu.batch.drawImage(sprite.image, pos, .{ .flipX = !flip });
    }

    for (map.startPaths) |start| {
        if (start == 0) break;

        var previous = map.paths.get(start).?;
        while (previous.next != 0) {
            const next = map.paths.get(previous.next).?;
            zhu.batch.drawLine(previous.point, next.point, .{
                .color = .red,
                .width = 4,
            });
            previous = next;
        }
    }

    std.log.info("command len: {}", .{zhu.batch.imageDrawCount()});
}
