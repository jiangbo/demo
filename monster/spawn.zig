const std = @import("std");
const zhu = @import("zhu");

const com = @import("component.zig");
const map = @import("map.zig");
const ctx = @import("context.zig");

const Registry = zhu.ecs.Registry;

pub const Sound = struct { action: com.ActionEnum, path: [:0]const u8 };
pub const Template = struct {
    enemyEnum: ?enum { slime, wolf, goblin, darkWitch } = null,
    playerEnum: ?com.PlayerEnum = null,
    name: []const u8,
    description: []const u8 = &.{},
    stats: com.Stats,
    range: f32,
    interval: f32,
    block: u8 = 0,
    cost: u8 = 0,
    speed: f32 = 0,
    attackKind: map.PlaceKind = .melee,
    faceRight: bool,
    projectile: ?com.ProjectileEnum = null,
    size: zhu.Vector2,
    offset: zhu.Vector2,
    sounds: []const Sound = &.{},
    image: struct { path: [:0]const u8, size: zhu.Vector2 },
    animations: []const []const zhu.graphics.Frame = &.{},
};

pub const enemyZon: []const Template = @import("zon/enemy.zon");
pub const playerZon: []const Template = @import("zon/player.zon");

pub fn spawnEnemies(reg: *Registry) void {
    for (map.startPaths) |startId| {
        if (startId == 0) break;

        const start = map.paths.get(startId).?;
        for (enemyZon) |*value| {
            const entity = doSpawn(reg, value);

            reg.add(entity, start.point);
            reg.add(entity, com.motion.Velocity{ .v = .zero });
            reg.add(entity, com.Enemy{
                .target = start,
                .speed = value.speed,
            });
            const index: u8 = @intFromEnum(com.StateEnum.walk);
            reg.getPtr(entity, com.Animation).play(index, true);
            std.log.info("spawn enemy: {}", .{entity.index});
        }
    }
}

fn doSpawn(reg: *Registry, zon: *const Template) zhu.ecs.Entity {
    const entity = reg.createEntity();

    const imagePath = zon.image.path;
    const image = zhu.assets.loadImage(imagePath, zon.image.size);
    reg.add(entity, com.Sprite{
        .image = image.sub(.init(.zero, zon.size)),
        .offset = zon.offset,
    });

    // 面向左侧
    if (!zon.faceRight) reg.add(entity, com.motion.FaceLeft{});

    if (zon.block != 0) {
        reg.add(entity, com.motion.Blocker{ .max = zon.block });
    }

    const animation = com.Animation.initSource(image, zon.animations);
    reg.add(entity, animation);

    // 添加攻击范围组件
    reg.add(entity, com.attack.Range{ .v = zon.range });

    // 添加远程攻击
    if (zon.attackKind == .ranged) reg.add(entity, com.attack.Ranged{});

    // 添加属性组件
    reg.add(entity, zon.stats);
    if (zon.stats.attack < 0) reg.add(entity, com.attack.Healer{});
    if (zon.stats.health < zon.stats.maxHealth) {
        reg.add(entity, com.attack.Injured{});
    }

    // 添加投射物组件
    if (zon.projectile) |value| reg.add(entity, value);

    // 攻击冷却时间
    reg.add(entity, com.attack.CoolDown{ .v = zon.interval });
    reg.add(entity, com.attack.Ready{});

    // 添加声音组件
    for (zon.sounds) |sound| {
        const path = sound.path;
        switch (sound.action) {
            .hit => reg.add(entity, com.audio.Hit{ .path = path }),
            .emit => reg.add(entity, com.audio.Emit{ .path = path }),
            else => {},
        }
    }
    return entity;
}

/// 尝试在合法出击区域部署玩家单位
pub fn tryDeployPlayer(reg: *Registry, playerEnum: com.PlayerEnum) void {
    const template = &playerZon[@intFromEnum(playerEnum)];
    const mousePos = zhu.window.mousePosition;

    if (map.findPlace(template.attackKind, mousePos)) |idx| {
        if (!ctx.canAfford(playerEnum)) return;

        const place = &map.places.items[idx];
        const center = place.position.add(place.size.scale(0.5));

        const entity = doSpawn(reg, template);
        reg.add(entity, center);
        reg.add(entity, com.Player{});
        place.entity = entity;

        ctx.spend(playerEnum);
        std.log.info("player deployed: {}", .{entity.index});
    }
}

/// 释放被该实体占用的出击点
pub fn releasePlace(entity: zhu.ecs.Entity) void {
    for (map.places.items) |*place| {
        if (place.entity) |pe| {
            if (std.meta.eql(pe, entity)) {
                place.entity = null;
                return;
            }
        }
    }
}

const Projectile = struct {
    image: [:0]const u8,
    position: zhu.Vector2,
    size: zhu.Vector2,
    offset: zhu.Vector2,
    arc: f32,
    time: f32,
};

const projectileZon: []const Projectile = @import("zon/projectile.zon");

pub fn projectile(reg: *Registry, delta: f32) void {
    defer reg.clear(com.attack.Emit);
    var view = reg.view(.{com.attack.Emit});
    while (view.next()) |entity| {
        // 检查目标是否还有效
        var targetPos: ?zhu.Vector2 = null;
        if (view.tryGet(entity, com.attack.Target)) |target| {
            if (reg.validEntity(target.v)) {
                targetPos = reg.get(target.v, com.Position);
            }
        }
        if (targetPos == null) continue; // 目标无效，跳过生成投射物

        const template = view.get(entity, com.ProjectileEnum);
        const value = &projectileZon[@intFromEnum(template)];

        const new = reg.createEntity();
        const image = zhu.assets.loadImage(value.image, .zero);
        reg.add(new, image.sub(.init(value.position, value.size)));
        reg.add(new, com.Projectile{
            .start = view.get(entity, com.Position),
            .end = targetPos.?,
            .arc = value.arc,
            .totalTime = value.time + delta,
            .owner = view.toEntity(entity),
            .offset = value.offset,
        });

        reg.add(new, view.get(entity, com.Position).add(value.offset));

        if (view.tryGet(entity, com.audio.Emit)) |emitSound| {
            zhu.audio.playSound(emitSound.path); // 播放发射声音
        }

        std.log.info("entity: {} emit: {}", .{ entity, new.index });
    }
}
