const std = @import("std");
const zhu = @import("zhu");

const actorConfig = @import("zon/actor.zon");
const component = @import("component.zig");
const farmConfig = @import("zon/farm.zon");

pub fn init() void {
    std.log.info("spawn init", .{});
}

pub fn loadFarm(world: *zhu.ecs.World) void {
    spawnFarmEntities(world);

    {
        const sprite = actorConfig.player.sprite;
        const playerImage = imageFromConfig(sprite);
        var query = world.query(.{component.Player});
        world.add(query.next().?, component.Sprite{
            .image = playerImage,
            .offset = .xy(sprite.offset.x, sprite.offset.y),
            .size = .xy(sprite.size.x, sprite.size.y),
        });
    }

    {
        const sprite = farmConfig.crop.sprite;
        var query = world.query(.{component.Crop});
        world.add(query.next().?, component.Sprite{
            .image = zhu.batch.whiteImage,
            .offset = .xy(sprite.offset.x, sprite.offset.y),
            .size = .xy(sprite.size.x, sprite.size.y),
        });
    }

    {
        const sprite = farmConfig.farmland.sprite;
        var query = world.query(.{component.Farmland});
        world.add(query.next().?, component.Sprite{
            .image = zhu.batch.whiteImage,
            .offset = .xy(sprite.offset.x, sprite.offset.y),
            .size = .xy(sprite.size.x, sprite.size.y),
        });
    }
}

fn spawnFarmEntities(world: *zhu.ecs.World) void {
    const player = world.createEntity();
    world.add(player, component.Player{});
    world.add(player, component.Position.xy(160, 96));
    world.add(player, component.Render{
        .layer = .actor,
    });
    world.add(player, component.YSort{});

    const crop = world.createEntity();
    world.add(crop, component.Crop{ .growth = 0 });
    world.add(crop, component.Position.xy(176, 96));
    world.add(crop, component.Render{
        .layer = .crop,
        .color = .rgb(0.24, 0.68, 0.28),
    });
    world.add(crop, component.YSort{});

    const farmland = world.createEntity();
    world.add(farmland, component.Farmland{});
    world.add(farmland, component.Position.xy(176, 112));
    world.add(farmland, component.Render{
        .layer = .ground,
        .color = .rgb(0.47, 0.28, 0.16),
    });

    std.log.info("farm loaded entities player={} crop={} farmland={}", .{
        player,
        crop,
        farmland,
    });
}

fn imageFromConfig(sprite: anytype) zhu.graphics.Image {
    const rect = zhu.Rect{
        .min = .xy(sprite.rect.min.x, sprite.rect.min.y),
        .size = .xy(sprite.rect.size.x, sprite.rect.size.y),
    };

    return zhu.getImage(sprite.path).sub(rect);
}

test "加载农场会创建初始实体" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    spawnFarmEntities(&world);

    const equal = std.testing.expectEqual;
    try equal(1, world.assure(component.Player).dense.items.len);
    try equal(1, world.raw(component.Crop).len);
    try equal(1, world.raw(component.Farmland).len);
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
