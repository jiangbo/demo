const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");

pub const Animation = struct {
    type: component.actor.Action,
    imageId: zhu.Id,
    frames: []const zhu.graphics.Frame,
};

pub const Actor = struct {
    sprite: Sprite,
    rows: [4]i8,
    animations: []const Animation,
};

pub const Animal = struct {
    sprite: Sprite,
    rows: [4]i8,
    animations: []const Animation,
    speed: f32,
    wanderRadius: f32,
};

pub const Sprite = struct {
    imageId: zhu.Id,
    rect: zhu.Rect,
    offset: zhu.Vector2 = .zero,
    size: zhu.Vector2,
};

pub const Item = struct {
    limit: u32 = 99,
    icon: Sprite,
};

pub const Farm = struct {
    items: [std.meta.fields(component.item.ItemEnum).len]Item,
    animals: [std.meta.fields(component.actor.AnimalKind).len]Animal,
    crop: struct {
        stages: [4]struct { sprite: Sprite, duration: f32 },
    },
};

pub const actor: struct { player: Actor } = @import("zon/actor.zon");
pub const farm: Farm = @import("zon/farm.zon");

pub fn item(itemType: component.item.ItemEnum) Item {
    return farm.items[@intFromEnum(itemType)];
}

pub fn resolveImage(sprite: Sprite) zhu.graphics.Image {
    return zhu.assets.getImage(sprite.imageId).?.sub(sprite.rect);
}

test "玩家图片配置来自 actor.zon" {
    const sprite = actor.player.sprite;

    try std.testing.expectEqual(2802575066, sprite.imageId);
    try std.testing.expectEqual(32, sprite.rect.size.x);
    try std.testing.expectEqual(32, sprite.rect.size.y);
    try std.testing.expectEqual(-16, sprite.offset.x);
    try std.testing.expectEqual(-24, sprite.offset.y);
}

test "作物配置包含四个阶段" {
    const stages = farm.crop.stages;
    try std.testing.expectEqual(0, stages[0].sprite.rect.min.x);
    try std.testing.expectEqual(16, stages[1].sprite.rect.min.x);
    try std.testing.expectEqual(32, stages[2].sprite.rect.min.x);
    try std.testing.expectEqual(80, stages[3].sprite.rect.min.x);
    try std.testing.expectEqual(4, stages.len);
}

test "工具物品不可堆叠" {
    try std.testing.expectEqual(1, item(.hoe).limit);
    try std.testing.expectEqual(1, item(.water).limit);
}
