const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;

const map = @import("map.zig");
const com = @import("component.zig");
const enemy = @import("enemy.zig");
const player = @import("player.zig");
const battle = @import("battle.zig");

var registry: ecs.Registry = undefined;
// var timer: zhu.Timer = .init(10);

pub fn init() void {
    registry = .init(zhu.assets.allocator);
    map.init();
    enemy.spawn(&registry);
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

    // 更新动画事件，切换显示的图片
    updateAnimation(delta);
    // 地图更新，地图上的动画等。
    map.update(delta);

    battle.cleanInvalidTarget(&registry);
    battle.selectTarget(&registry);

    enemy.move(&registry, delta);
    enemy.followPath(&registry);

    // 处理到达终点的敌人
    for (registry.getEvents(ecs.Entity)) |entity| {
        registry.destroyEntity(entity);
    }
    registry.clearEvent(ecs.Entity);
}

fn updateAnimation(delta: f32) void {
    var view = registry.view(.{zhu.graphics.Animation});
    while (view.next()) |entity| {
        const animation = view.getPtr(entity, zhu.graphics.Animation);
        if (animation.isNextLoopUpdate(delta)) {
            const sprite = view.getPtr(entity, com.Sprite);
            sprite.image = animation.subImage(sprite.image.size);
        }
    }
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

        var flip = sprite.flip;
        const face = view.tryGet(entity, com.Face);
        if (face) |f| flip = (f == .Left) != flip;
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

    // std.log.info("command len: {}", .{zhu.batch.imageDrawCount()});
}
