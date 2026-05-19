const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");

pub const Animation = struct {
    type: component.PlayerAnimation,
    path: [:0]const u8,
    frames: []const zhu.graphics.Frame,
};

pub const Actor = struct {
    sprite: struct {
        path: [:0]const u8,
        rect: zhu.Rect,
        size: zhu.Vector2,
        offset: zhu.Vector2,
    },
    rows: [4]i8,
    animations: []const Animation,
};

pub const Sprite = struct {
    path: [:0]const u8,
    rect: zhu.Rect,
    offset: zhu.Vector2 = .zero,
    size: zhu.Vector2,
};

pub const Farm = struct {
    crop: struct {
        stages: struct {
            seed: Sprite,
            sprout: Sprite,
            growing: Sprite,
            mature: Sprite,
        },
        durations: [4]f32,
    },
    farmland: struct {
        dry: Sprite,
        wet: Sprite,
    },
};

pub const actor: struct { player: Actor } = @import("zon/actor.zon");
pub const farm: Farm = @import("zon/farm.zon");

test "玩家图片配置来自 actor.zon" {
    const sprite = actor.player.sprite;

    try std.testing.expectEqual(2802575066, zhu.id(sprite.path));
    try std.testing.expectEqual(32, sprite.rect.size.x);
    try std.testing.expectEqual(32, sprite.rect.size.y);
    try std.testing.expectEqual(-16, sprite.offset.x);
    try std.testing.expectEqual(-24, sprite.offset.y);
}

test "农田配置包含干湿两种贴图" {
    try std.testing.expectEqual(0, farm.farmland.dry.rect.min.x);
    try std.testing.expectEqual(192, farm.farmland.wet.rect.min.x);
    try std.testing.expectEqual(48, farm.farmland.dry.rect.min.y);
    try std.testing.expectEqual(48, farm.farmland.wet.rect.min.y);
}

test "作物配置包含四个阶段" {
    try std.testing.expectEqual(0, farm.crop.stages.seed.rect.min.x);
    try std.testing.expectEqual(16, farm.crop.stages.sprout.rect.min.x);
    try std.testing.expectEqual(32, farm.crop.stages.growing.rect.min.x);
    try std.testing.expectEqual(80, farm.crop.stages.mature.rect.min.x);
    try std.testing.expectEqual(4, farm.crop.durations.len);
}
