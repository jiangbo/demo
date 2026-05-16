const std = @import("std");
const zhu = @import("zhu");

const actorConfig = @import("zon/actor.zon");
const component = @import("component.zig");
const farmConfig = @import("zon/farm.zon");

pub fn init() void {
    std.log.info("spawn init", .{});
}

pub fn loadFarm(world: *zhu.ecs.World) void {
    {
        const sprite = actorConfig.player.sprite;
        const player = world.createEntity();
        world.add(player, component.Player{});
        world.add(player, component.Position.xy(160, 96));
        world.add(player, component.Sprite{
            .image = imageFromConfig(sprite),
            .offset = .xy(sprite.offset.x, sprite.offset.y),
            .size = .xy(sprite.size.x, sprite.size.y),
        });
        world.add(player, component.Render{ .layer = .actor });
        world.add(player, component.YSort{});
    }

    {
        const sprite = farmConfig.crop.sprite;
        const crop = world.createEntity();
        world.add(crop, component.Crop{ .growth = 0 });
        world.add(crop, component.Position.xy(176, 96));
        world.add(crop, component.Sprite{
            .image = imageFromConfig(sprite),
            .offset = .xy(sprite.offset.x, sprite.offset.y),
            .size = .xy(sprite.size.x, sprite.size.y),
        });
        world.add(crop, component.Render{ .layer = .crop });
        world.add(crop, component.YSort{});
    }

    {
        const sprite = farmConfig.farmland.sprite;
        const farmland = world.createEntity();
        world.add(farmland, component.Farmland{});
        world.add(farmland, component.Position.xy(176, 112));
        world.add(farmland, component.Sprite{
            .image = imageFromConfig(sprite),
            .offset = .xy(sprite.offset.x, sprite.offset.y),
            .size = .xy(sprite.size.x, sprite.size.y),
        });
        world.add(farmland, component.Render{ .layer = .ground });
    }
}

fn imageFromConfig(sprite: anytype) zhu.graphics.Image {
    const rect = zhu.Rect{
        .min = .xy(sprite.rect.min.x, sprite.rect.min.y),
        .size = .xy(sprite.rect.size.x, sprite.rect.size.y),
    };

    if (zhu.getImage(sprite.path)) |image| return image.sub(rect);
    return zhu.batch.whiteImage.sub(rect);
}

test "加载农场会创建初始实体" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    loadFarm(&world);

    const equal = std.testing.expectEqual;
    try equal(1, world.assure(component.Player).dense.items.len);
    try equal(1, world.raw(component.Crop).len);
    try equal(1, world.raw(component.Farmland).len);
    try equal(3, world.raw(component.Sprite).len);
    try equal(3, world.raw(component.Render).len);
    try equal(2, world.assure(component.YSort).dense.items.len);
}

test "玩家图片配置来自 actor.zon" {
    const sprite = actorConfig.player.sprite;

    try std.testing.expectEqual(2802575066, zhu.id(sprite.path));
    try std.testing.expectEqual(32, sprite.rect.size.x);
    try std.testing.expectEqual(32, sprite.rect.size.y);
    try std.testing.expectEqual(-16, sprite.offset.x);
    try std.testing.expectEqual(-24, sprite.offset.y);
}
