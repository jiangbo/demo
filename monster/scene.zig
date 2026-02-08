const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;

const map = @import("map.zig");
const com = @import("component.zig");
const spawn = @import("spawn.zig");
const battle = @import("battle.zig");

const system = struct {
    const motion = @import("system/motion.zig");
    const state = @import("system/state.zig");
    const animation = @import("system/animation.zig");
};

var registry: ecs.Registry = undefined;
// var timer: zhu.Timer = .init(10);

pub fn init() void {
    registry = .init(zhu.assets.allocator);
    map.init();
    spawn.spawnEnemies(&registry);
}

pub fn deinit() void {
    map.deinit();
    registry.deinit();
}

pub fn update(delta: f32) void {
    // if (timer.isFinishedLoopUpdate(delta)) enemy.spawn(&registry);

    if (zhu.window.mouse.pressed(.LEFT)) {
        spawn.spawnPlayer(&registry, .warrior);
    } else if (zhu.window.mouse.pressed(.RIGHT)) {
        spawn.spawnPlayer(&registry, .archer);
    }

    // 地图更新，地图上的动画等。
    map.update(delta);

    system.motion.update(&registry, delta); // 移动系统
    system.animation.update(&registry, delta); // 动画系统
    system.state.update(&registry, delta); // 状态系统

    battle.cleanAttackTimerIfDone(&registry, delta);
    battle.cleanInvalidTarget(&registry);
    battle.attack(&registry);

    // 处理动画事件，转换为战斗事件
    battle.processAnimationEvents(&registry);

    // 处理战斗结算
    // battle.resolveCombat(&registry);

    // 处理攻击事件（开始攻击动画）
    for (registry.getEvents(com.AttackEvent)) |event| {
        // 播放攻击动画
        const attacker = event.attacker;
        registry.add(attacker, com.AnimationPlay{
            .index = @intFromEnum(com.StateEnum.attack),
        });

        registry.add(attacker, com.AttackTimer{ .v = .init(2) });
    }

    // 处理到达终点的敌人
    for (registry.getEvents(ecs.Entity)) |entity| {
        registry.destroyEntity(entity);
    }
    registry.clearEvent(ecs.Entity);
    registry.clearEvent(com.AttackEvent);
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
        if (face) |f| flip = (f == .left) != flip;
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
