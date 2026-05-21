const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const prefab = @import("prefab.zig");

const World = zhu.ecs.World;
const Entity = zhu.ecs.Entity;

pub fn init() void {
    std.log.info("spawn init", .{});
}

pub fn loadFarm(world: *World) void {
    const config = prefab.actor.player;

    const player = world.createIdentityEntity(component.Player);
    world.add(player, component.Position.xy(160, 96));
    world.add(player, component.Velocity{});
    world.add(player, component.Actor{ .rows = config.rows });

    const sources = comptime animationSources(config.animations);
    const animation = zhu.Animation.initSource(&sources);

    world.add(player, component.Sprite{
        .image = animation.image,
        .offset = config.sprite.offset,
        .size = config.sprite.size,
    });

    world.add(player, animation);
    world.add(player, component.Render{ .layer = .actor });
    world.add(player, component.YSort{});
    world.add(player, component.Target{});
}

pub fn spawnCrop(world: *World, position: zhu.Vector2) Entity {
    const stage = prefab.farm.crop.stages[0];
    const entity = world.createEntity();
    world.add(entity, component.Crop{ .next = stage.duration });
    world.add(entity, component.Position.xy(position.x, position.y));
    world.add(entity, component.Sprite{
        .image = prefab.resolveImage(stage.sprite),
        .offset = stage.sprite.offset,
    });
    world.add(entity, component.Render{ .layer = .crop });
    world.add(entity, component.YSort{});
    return entity;
}

pub fn advanceCrop(crop: *component.Crop) component.Sprite {
    crop.timer = 0;
    crop.stage = zhu.nextEnum(component.GrowthEnum, crop.stage);
    const stage = prefab.farm.crop.stages[@intFromEnum(crop.stage)];
    crop.next = stage.duration;
    return .{
        .image = prefab.resolveImage(stage.sprite),
        .offset = stage.sprite.offset,
    };
}

pub fn spawnPickup(world: *World, item: component.ItemEnum) Entity {
    const config = prefab.item(item);

    const entity = world.createEntity();
    world.add(entity, component.Pickup{ .item = item, .count = 1 });
    world.add(entity, component.Sprite{
        .image = prefab.resolveImage(config.icon),
        .size = .xy(10, 10),
    });
    world.add(entity, component.Render{ .layer = .crop });
    world.add(entity, component.YSort{});
    return entity;
}

fn animationSources(comptime animations: []const prefab.Animation) //
[animations.len]zhu.Animation.Source {
    var sources: [animations.len]zhu.Animation.Source = undefined;
    inline for (animations) |config| {
        sources[@intFromEnum(config.type)] = .{
            .imageId = config.imageId,
            .clip = config.frames,
        };
    }
    return sources;
}

const expectEqual = std.testing.expectEqual;
test "加载农场会创建初始实体" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockFarmImages();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    loadFarm(&world);

    const player = world.getIdentityEntity(component.Player).?;
    try expectEqual(160, world.get(player, component.Position).?.x);
    try expectEqual(1, world.raw(component.Velocity).len);
    try expectEqual(1, world.raw(component.Actor).len);
    try expectEqual(1, world.raw(component.Sprite).len);
    try expectEqual(1, world.raw(component.Render).len);
    try expectEqual(1, world.assure(component.YSort).dense.items.len);
}

test "spawnCrop 创建作物实体并设置初始 next" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockCropImages();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const entity = spawnCrop(&world, .xy(32, 48));
    const crop = world.get(entity, component.Crop).?;
    try expectEqual(component.GrowthEnum.seed, crop.stage);
    try expectEqual(prefab.farm.crop.stages[0].duration, crop.next);
    try expectEqual(32, world.get(entity, component.Position).?.x);
}

test "advanceCrop 推进阶段并累加 next" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockCropImages();

    var crop = component.Crop{
        .next = prefab.farm.crop.stages[0].duration,
    };
    _ = advanceCrop(&crop);
    try expectEqual(component.GrowthEnum.sprout, crop.stage);
    try expectEqual(prefab.farm.crop.stages[1].duration, crop.next);
    try expectEqual(@as(f32, 0), crop.timer);
}

fn putMockFarmImages() void {
    const image = zhu.graphics.Image{
        .texture = .{ .id = 1 },
        .size = .xy(256, 256),
    };

    for (prefab.actor.player.animations) |animation| {
        zhu.assets.putImage(animation.imageId, image);
    }
}

fn putMockCropImages() void {
    const image = zhu.graphics.Image{
        .texture = .{ .id = 1 },
        .size = .xy(256, 256),
    };
    for (prefab.farm.crop.stages) |stage| {
        zhu.assets.putImage(stage.sprite.imageId, image);
    }
}
