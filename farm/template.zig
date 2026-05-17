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
    directions: []const component.Facing,
    animations: []const Animation,
};

pub const Sprite = struct {
    path: [:0]const u8,
    rect: zhu.Rect,
    offset: zhu.Vector2,
    size: zhu.Vector2,
};

pub const Farm = struct {
    crop: struct {
        sprite: Sprite,
    },
    farmland: struct {
        sprite: Sprite,
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
