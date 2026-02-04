const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;

const com = @import("component.zig");

const Animation = zhu.graphics.MultiAnimation;
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

const zon: std.EnumArray(Enum, Player) = @import("zon/player.zon");

pub fn spawn(registry: *ecs.Registry, playerEnum: Enum) void {
    const value = zon.get(playerEnum);
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

    const animation: Animation = .init(image, value.animations);
    registry.add(player, animation);

    // 添加攻击范围组件
    if (value.playerEnum != .witch) {
        registry.add(player, com.AttackRange{ .v = value.range });
    }
}
