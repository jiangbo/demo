const std = @import("std");
const zhu = @import("zhu");

const map = @import("map.zig");
const com = @import("component.zig");
const spawn = @import("spawn.zig");
const battle = @import("battle.zig");

const system = struct {
    const motion = @import("system/motion.zig");
    const state = @import("system/state.zig");
    const target = @import("system/target.zig");
    const attack = @import("system/attack.zig");
    const facing = @import("system/facing.zig");
    const animation = @import("system/animation.zig");
};

var registry: zhu.ecs.Registry = undefined;

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
    if (zhu.window.mouse.pressed(.LEFT)) {
        spawn.spawnPlayer(&registry, .warrior);
    } else if (zhu.window.mouse.pressed(.RIGHT)) {
        spawn.spawnPlayer(&registry, .archer);
    }

    // 地图更新，地图上的动画等。
    map.update(delta);

    cleanTimerIfDone(com.AttackTimer, delta); // 清理攻击计时器

    system.motion.update(&registry, delta); // 移动系统
    system.animation.update(&registry, delta); // 动画系统
    system.state.update(&registry, delta); // 状态系统
    system.target.update(&registry, delta); // 目标系统
    system.attack.update(&registry, delta); // 攻击系统
    system.facing.update(&registry, delta); // 面向系统

    // 处理动画事件，转换为战斗事件
    battle.processAnimationEvents(&registry);

    // 处理战斗结算
    // battle.resolveCombat(&registry);

    // 处理到达终点的敌人
    for (registry.getEvents(zhu.ecs.Entity)) |entity| {
        registry.destroyEntity(entity);
    }
    registry.clearEvent(zhu.ecs.Entity);
}

///
///  删除已经结束的计时器。
///
pub fn cleanTimerIfDone(T: type, delta: f32) void {
    var view = registry.reverseView(.{T});
    while (view.next()) |entity| {
        const timer = view.getPtr(entity, T);
        if (timer.v.isFinishedOnceUpdate(delta)) {
            view.remove(entity, T);
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

        zhu.batch.drawImage(sprite.image, pos, .{
            .flipX = sprite.flip,
        });
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
