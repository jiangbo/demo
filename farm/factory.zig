const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const prefab = @import("prefab.zig");

const actor = component.actor;
const farm = component.farm;
const item = component.item;
const map = component.map;
const motion = component.motion;
const render = component.render;
const ui = component.ui;

const World = zhu.ecs.World;
const Entity = zhu.ecs.Entity;
const Object = zhu.extend.tiled.Object;
const Image = zhu.graphics.Image;

pub fn init() void {
    std.log.info("spawn init", .{});
}

pub fn loadFarm(world: *World) void {
    const config = prefab.actor.player;

    const player = world.createIdentity(actor.Player);
    world.add(player, component.Position.xy(160, 96));
    world.add(player, motion.Velocity{});
    world.add(player, motion.Collider{
        .size = .xy(10, 6),
        .offset = .xy(-5, -6),
    });
    world.add(player, actor.Actor{ .rows = config.rows });

    const sources = comptime animationSources(config.animations);
    const animation = zhu.Animation.initSource(&sources);

    world.add(player, render.Sprite{
        .image = animation.image,
        .offset = config.sprite.offset,
        .size = config.sprite.size,
    });

    world.add(player, animation);
    world.add(player, render.Render{ .layer = .actor });
    world.add(player, render.YSort{});
    world.add(player, ui.Target{});
}

pub fn spawnMapProp(world: *World, object: Object, image: Image) Entity {
    const hasSize = object.size.x > 0 and object.size.y > 0;
    const size = if (hasSize) object.size else image.size;

    const entity = world.createEntity();
    world.add(entity, object.position);
    world.add(entity, render.Sprite{
        .image = image,
        .offset = .xy(0, -size.y),
        .size = size,
        .flip = object.extend.flipX,
    });
    world.add(entity, render.Render{ .layer = .actor });
    world.add(entity, render.YSort{});
    world.add(entity, map.Scoped{});
    return entity;
}

pub fn spawnMapTrigger(world: *World, trigger: map.Trigger) Entity {
    const entity = world.createEntity();
    world.add(entity, trigger);
    world.add(entity, map.Scoped{});
    return entity;
}

pub fn spawnCrop(world: *World, position: zhu.Vector2) Entity {
    const stage = prefab.farm.crop.stages[0];
    const entity = world.createEntity();
    world.add(entity, farm.Crop{ .next = stage.duration });
    world.add(entity, component.Position.xy(position.x, position.y));
    world.add(entity, render.Sprite{
        .image = prefab.resolveImage(stage.sprite),
        .offset = stage.sprite.offset,
    });
    world.add(entity, render.Render{ .layer = .crop });
    world.add(entity, render.YSort{});
    world.add(entity, map.Scoped{});
    return entity;
}

pub fn advanceCrop(crop: *farm.Crop) render.Sprite {
    crop.timer = 0;
    crop.stage = zhu.nextEnum(farm.GrowthEnum, crop.stage);
    const stage = prefab.farm.crop.stages[@intFromEnum(crop.stage)];
    crop.next = stage.duration;
    return .{
        .image = prefab.resolveImage(stage.sprite),
        .offset = stage.sprite.offset,
    };
}

pub fn spawnPickup(world: *World, itemType: item.ItemEnum) Entity {
    const config = prefab.item(itemType);

    const entity = world.createEntity();
    world.add(entity, item.Pickup{ .item = itemType, .count = 1 });
    world.add(entity, render.Sprite{
        .image = prefab.resolveImage(config.icon),
        .size = .xy(10, 10),
    });
    world.add(entity, render.Render{ .layer = .crop });
    world.add(entity, render.YSort{});
    world.add(entity, map.Scoped{});
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

    const player = world.getIdentity(actor.Player).?;
    try expectEqual(160, world.get(player, component.Position).?.x);
    try expectEqual(1, world.raw(motion.Velocity).len);
    try expectEqual(1, world.raw(actor.Actor).len);
    try expectEqual(1, world.raw(render.Sprite).len);
    try expectEqual(1, world.raw(render.Render).len);
    try expectEqual(1, world.assure(render.YSort).dense.items.len);
}

test "spawnCrop 创建作物实体并设置初始 next" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockCropImages();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const entity = spawnCrop(&world, .xy(32, 48));
    const crop = world.get(entity, farm.Crop).?;
    try expectEqual(farm.GrowthEnum.seed, crop.stage);
    try expectEqual(prefab.farm.crop.stages[0].duration, crop.next);
    try expectEqual(32, world.get(entity, component.Position).?.x);
}

test "advanceCrop 推进阶段并累加 next" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockCropImages();

    var crop = farm.Crop{
        .next = prefab.farm.crop.stages[0].duration,
    };
    _ = advanceCrop(&crop);
    try expectEqual(farm.GrowthEnum.sprout, crop.stage);
    try expectEqual(prefab.farm.crop.stages[1].duration, crop.next);
    try expectEqual(@as(f32, 0), crop.timer);
}

test "地图摆件按底边定位生成实体" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    const image = zhu.graphics.Image{
        .texture = .{ .id = 1 },
        .size = .xy(16, 16),
    };

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const entity = spawnMapProp(&world, .{
        .id = 1,
        .gid = 1,
        .name = "",
        .type = "",
        .position = .xy(12, 34),
        .size = .xy(20, 30),
        .point = false,
        .properties = &.{},
        .extend = .{},
    }, image);

    const position = world.get(entity, component.Position).?;
    const sprite = world.get(entity, render.Sprite).?;

    try expectEqual(@as(f32, 12), position.x);
    try expectEqual(@as(f32, 34), position.y);
    try expectEqual(@as(f32, -30), sprite.offset.y);
    try expectEqual(@as(f32, 20), sprite.size.?.x);
    try expectEqual(@as(f32, 30), sprite.size.?.y);
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
