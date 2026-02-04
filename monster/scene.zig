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

    enemy.move(&registry, delta);
    enemy.followPath(&registry);

    battle.cleanAttackTimerIfDone(&registry, delta);
    battle.cleanInvalidTarget(&registry);
    battle.attack(&registry);

    // 处理攻击事件
    for (registry.getEvents(com.AttackEvent)) |event| {
        // 目前先播放一个攻击动画
        const attacker = event.attacker;
        const ani = registry.getPtr(attacker, zhu.MultiAnimation);
        ani.change(@intFromEnum(com.StateEnum.attack));

        registry.add(attacker, com.AttackTimer{ .v = .init(2) });
    }

    // 处理到达终点的敌人
    for (registry.getEvents(ecs.Entity)) |entity| {
        registry.destroyEntity(entity);
    }
    registry.clearEvent(ecs.Entity);
    registry.clearEvent(com.AttackEvent);
}

fn updateAnimation(delta: f32) void {
    var view = registry.view(.{zhu.MultiAnimation});
    while (view.next()) |ent| {
        const animation = view.getPtr(ent, zhu.MultiAnimation);
        if (!animation.v.isNextOnceUpdate(delta)) continue; // 动画未跳到下一帧

        if (animation.v.isRunning()) { // 动画还在运行，并且切换到下一帧了。
            const sprite = view.getPtr(ent, com.Sprite);
            sprite.image = animation.v.subImage(sprite.image.size);
            continue;
        }

        // 动画播放结束，切换动画，需要根据角色和敌人来区分
        if (view.has(ent, com.Enemy)) {
            // 敌人需要区分是否被阻挡
            if (view.has(ent, com.BlockBy)) {
                animation.change(@intFromEnum(com.StateEnum.idle));
            } else {
                animation.change(@intFromEnum(com.StateEnum.walk));
            }
        } else {
            animation.change(@intFromEnum(com.StateEnum.idle));
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
