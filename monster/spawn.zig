const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;

const com = @import("component.zig");
const map = @import("map.zig");

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
    sounds: []const com.SoundPath = &.{},
    image: struct { path: [:0]const u8, size: zhu.Vector2 },
    animations: []const []const zhu.graphics.Frame = &.{},
};

const enemyZon: []const Enemy = @import("zon/enemy.zon");
const playerZon: std.EnumArray(Enum, Player) = @import("zon/player.zon");

pub fn spawnEnemies(registry: *ecs.Registry) void {
    for (map.startPaths) |startId| {
        if (startId == 0) break;

        const start = map.paths.get(startId).?;
        for (enemyZon) |value| {
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

            var animation = com.Animation.initSource(image, value.animations);
            animation.play(@intFromEnum(com.StateEnum.walk));
            registry.add(enemy, animation);

            // 添加属性组件
            registry.add(enemy, com.Stats{
                .hp = @floatFromInt(value.health),
                .maxHp = @floatFromInt(value.health),
                .atk = @floatFromInt(value.attack),
                .def = @floatFromInt(value.defense),
            });

            // 添加声音组件
            registry.add(enemy, value.sounds);

            // 添加攻击范围组件
            registry.add(enemy, com.AttackRange{ .v = value.range });
        }
    }
}

pub const Enum = enum { warrior, archer, lancer, witch };
const Player = struct {
    playerEnum: Enum,
    name: []const u8,
    description: []const u8,
    health: u32,
    attack: u32,
    defense: u32,
    range: f32,
    interval: f32,
    block: u8,
    cost: u8,
    faceRight: bool,
    size: zhu.Vector2,
    offset: zhu.Vector2,
    image: struct { path: [:0]const u8, size: zhu.Vector2 },
    animations: []const []const zhu.graphics.Frame = &.{},
};

pub fn spawnPlayer(registry: *ecs.Registry, playerEnum: Enum) void {
    const value = playerZon.get(playerEnum);
    const player = registry.createEntity();
    registry.add(player, zhu.window.mousePosition);
    registry.add(player, com.Player{});

    const path = value.image.path;
    const image = zhu.assets.loadImage(path, value.image.size);
    registry.add(player, com.Sprite{
        .image = image.sub(.init(.zero, value.size)),
        .offset = value.offset,
        .flip = value.faceRight,
    });

    if (value.block != 0) {
        registry.add(player, com.Blocker{ .max = value.block });
    }

    const animation = com.Animation.initSource(image, value.animations);
    registry.add(player, animation);

    // 添加属性组件
    registry.add(player, com.Stats{
        .hp = @floatFromInt(value.health),
        .maxHp = @floatFromInt(value.health),
        .atk = @floatFromInt(value.attack),
        .def = @floatFromInt(value.defense),
    });

    // 添加攻击范围组件
    if (value.playerEnum != .witch) {
        registry.add(player, com.AttackRange{ .v = value.range });
    }
}
