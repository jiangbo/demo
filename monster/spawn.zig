const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;

const com = @import("component.zig");
const map = @import("map.zig");

pub const PlayerEnum = enum { warrior, archer, lancer, witch };
const Template = struct {
    enemyEnum: ?enum { slime, wolf, goblin, darkWitch } = null,
    playerEnum: ?PlayerEnum = null,
    name: []const u8,
    description: []const u8 = &.{},
    health: u32,
    attack: u32,
    defense: u32,
    range: f32,
    interval: f32,
    block: u8 = 0,
    cost: u8 = 0,
    speed: f32 = 0,
    ranged: bool = false,
    faceRight: bool,
    size: zhu.Vector2,
    offset: zhu.Vector2,
    sounds: []const com.SoundPath = &.{},
    image: struct { path: [:0]const u8, size: zhu.Vector2 },
    animations: []const []const zhu.graphics.Frame = &.{},
};

const enemyZon: []const Template = @import("zon/enemy.zon");
const playerZon: []const Template = @import("zon/player.zon");

pub fn spawnEnemies(reg: *ecs.Registry) void {
    for (map.startPaths) |startId| {
        if (startId == 0) break;

        const start = map.paths.get(startId).?;
        for (enemyZon) |*value| {
            const entity = doSpawn(reg, value);

            reg.add(entity, start.point);
            reg.add(entity, com.Velocity{ .v = .zero });
            reg.add(entity, com.Enemy{
                .target = start,
                .speed = value.speed,
            });
            const index: u8 = @intFromEnum(com.StateEnum.walk);
            reg.getPtr(entity, com.Animation).play(index, true);
        }
    }
}

fn doSpawn(reg: *ecs.Registry, zon: *const Template) ecs.Entity {
    const entity = reg.createEntity();

    const path = zon.image.path;
    const image = zhu.assets.loadImage(path, zon.image.size);
    reg.add(entity, com.Sprite{
        .image = image.sub(.init(.zero, zon.size)),
        .offset = zon.offset,
    });

    // 面向左侧
    if (!zon.faceRight) reg.add(entity, com.FaceLeft{});

    if (zon.block != 0) {
        reg.add(entity, com.Blocker{ .max = zon.block });
    }

    const animation = com.Animation.initSource(image, zon.animations);
    reg.add(entity, animation);

    // 添加攻击范围组件
    if (zon.playerEnum != .witch) {
        reg.add(entity, com.AttackRange{ .v = zon.range });
    }

    // 添加远程攻击
    if (zon.ranged) reg.add(entity, com.Ranged{});

    // 添加属性组件
    reg.add(entity, com.Stats{
        .hp = @floatFromInt(zon.health),
        .maxHp = @floatFromInt(zon.health),
        .atk = @floatFromInt(zon.attack),
        .def = @floatFromInt(zon.defense),
    });

    // 攻击冷却时间
    reg.add(entity, com.CoolDown{ .v = zon.interval });

    // 添加声音组件
    reg.add(entity, zon.sounds);

    return entity;
}

pub fn spawnPlayer(reg: *ecs.Registry, playerEnum: PlayerEnum) void {
    const value = &playerZon[@intFromEnum(playerEnum)];

    const entity = doSpawn(reg, value);
    reg.add(entity, zhu.window.mousePosition);
    reg.add(entity, com.Player{});
}
