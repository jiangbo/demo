const std = @import("std");
const zhu = @import("zhu");

const map = @import("map.zig");
const com = @import("component.zig");
const spawn = @import("spawn.zig");
const battle = @import("battle.zig");

const system = struct {
    const timer = @import("system/timer.zig");
    const motion = @import("system/motion.zig");
    const state = @import("system/state.zig");
    const target = @import("system/target.zig");
    const projectile = @import("system/projectile.zig");
    const attack = @import("system/attack.zig");
    const health = @import("system/health.zig");
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
    } else if (zhu.window.mouse.pressed(.MIDDLE)) {
        spawn.spawnPlayer(&registry, .witch);
    }

    // 地图更新，地图上的动画等。
    map.update(delta);

    system.timer.update(&registry, delta); // 计时系统

    system.motion.update(&registry, delta); // 移动系统
    system.animation.update(&registry, delta); // 动画系统
    system.state.update(&registry, delta); // 状态系统
    system.target.update(&registry, delta); // 目标系统
    system.projectile.update(&registry, delta); // 投射物系统
    system.attack.update(&registry, delta); // 攻击系统
    system.health.update(&registry, delta); // 生命系统
    system.facing.update(&registry, delta); // 面向系统

    // 处理到达终点的敌人
    for (registry.getEvents(zhu.ecs.Entity).items) |entity| {
        registry.destroyEntity(entity);
    }

    registry.clearEvent(zhu.ecs.Entity);
}

pub fn draw() void {
    map.draw();

    // registry.sort(com.Sprite, struct {
    //     pub fn lessThan(a: com.Sprite, b: com.Sprite) bool {
    //         return a.image.texture.id < b.image.texture.id;
    //     }
    // }.lessThan);

    registry.sort(com.Position, struct {
        pub fn lessThan(a: com.Position, b: com.Position) bool {
            return a.y < b.y;
        }
    }.lessThan);

    var view = registry.view(.{ com.Position, com.Sprite });
    while (view.next()) |entity| {
        const sprite = view.get(entity, com.Sprite);
        const position = view.get(entity, com.Position);
        const pos = position.add(sprite.offset);

        zhu.batch.drawImage(sprite.image, pos, .{
            .flipX = sprite.flip,
        });
    }

    system.health.draw(&registry); // 绘制血条
    system.projectile.draw(&registry); // 绘制投射物

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
