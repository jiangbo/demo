const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const context = @import("context.zig");
const prefab = @import("prefab.zig");

const actor = component.actor;
const farm = component.farm;
const item = component.item;
const light = component.light;
const map = component.map;
const motion = component.motion;
const render = component.render;
const ui = component.ui;

const World = zhu.ecs.World;
const Entity = zhu.ecs.Entity;
const tiled = zhu.extend.tiled;
const Object = tiled.Object;

pub fn init() void {
    std.log.info("spawn init", .{});
}

pub fn spawnPlayer(world: *World, spawn: zhu.Vector2) void {
    if (world.getIdentity(actor.Player)) |oldPlayer| {
        world.destroyEntity(oldPlayer);
        _ = world.removeIdentity(actor.Player);
    }

    const config = prefab.actor.player;

    const player = world.createIdentity(actor.Player);
    world.add(player, spawn);
    world.add(player, motion.Velocity{});
    world.add(player, motion.Collider{
        .circle = .init(.xy(0, -5), 5),
    });
    world.add(player, actor.Actor{ .rows = config.rows });

    const sources = comptime animationSources(config.animations);
    const size = config.sprite.rect.size;
    const animation = zhu.Animation.initSource(&sources, size);

    world.add(player, render.Sprite{
        .image = animation.subImage(),
        .offset = config.sprite.offset,
        .size = config.sprite.size,
    });

    world.add(player, animation);
    world.add(player, render.Render{ .layer = .actor });
    world.add(player, render.YSort{});
    world.add(player, ui.Target{});
}

pub fn spawnAnimal(world: *World, kind: actor.AnimalKind) Entity {
    const config = prefab.farm.animals[@intFromEnum(kind)];

    const entity = world.createEntity();
    world.add(entity, motion.Velocity{});
    world.add(entity, motion.Collider{
        .circle = .init(.xy(0, -5), 5),
    });
    world.add(entity, actor.Actor{ .rows = config.rows });

    const animals = prefab.farm.animals;
    const sources = switch (kind) {
        .cow => &comptime animationSources(animals[0].animations),
        .sheep => &comptime animationSources(animals[1].animations),
    };
    const animation = zhu.Animation.initSource(sources, config.sprite.rect.size);

    world.add(entity, render.Sprite{
        .image = animation.subImage(),
        .offset = config.sprite.offset,
        .size = config.sprite.size,
    });
    world.add(entity, animation);
    world.add(entity, render.Render{ .layer = .actor });
    world.add(entity, render.YSort{});
    world.add(entity, map.Scoped{});
    world.add(entity, actor.Npc{});
    world.add(entity, actor.Animal{ .kind = kind });
    world.add(entity, actor.Wander{
        .radius = config.wanderRadius,
        .speed = config.speed,
    });
    world.add(entity, actor.Dialog{
        .scriptId = switch (kind) {
            .cow => "cow",
            .sheep => "sheep",
        },
    });

    return entity;
}

pub fn spawnMapProp(world: *World, data: *const tiled.Map, object: Object) Entity {
    const entity = world.createEntity();

    var image: zhu.graphics.Image = undefined;
    const tile = data.getTileByGid(object.gid).?;
    if (tile.animation.len > 0) {
        var animation = data.getAnimationByGid(object.gid).?;
        image = animation.subImage();
        // anim_id 表示由玩法触发的动画，地图加载时只挂组件不自动播放。
        if (tile.hasProperty("anim_id")) {
            animation.loop = false;
            animation.stop();
        }
        world.add(entity, animation);
    } else {
        image = data.getImageByGid(object.gid);
    }

    const hasSize = object.size.x > 0 and object.size.y > 0;
    const size = if (hasSize) object.size else image.size;
    const drawPosition = object.position.addY(-size.y);
    const sortY = mapPropSortY(object, tile, size);
    const sortPosition = zhu.Vector2.xy(object.position.x, sortY);

    world.add(entity, sortPosition);
    world.add(entity, render.Sprite{
        .image = image,
        .offset = drawPosition.sub(sortPosition),
        .size = size,
        .flip = object.extend.flipX,
    });
    world.add(entity, render.Render{ .layer = .actor });
    world.add(entity, render.YSort{});
    world.add(entity, map.Scoped{});
    return entity;
}

fn mapPropSortY(object: Object, tile: *const tiled.Tile, size: zhu.Vector2) f32 {
    const group = tile.objectGroup orelse return object.position.y;
    var result: f32 = 0;
    var found = false;

    for (group.objects) |local| {
        if (local.size.x <= 0 or local.size.y <= 0) continue;

        // Tiled 瓦片对象 position 是图片底边，碰撞框坐标从图片左上角开始。
        const bottom = object.position.y - size.y + local.position.y + local.size.y;
        if (!found or bottom > result) {
            result = bottom;
            found = true;
        }
    }

    return if (found) result else object.position.y;
}

pub fn spawnMapTrigger(world: *World, trigger: map.Trigger) Entity {
    const entity = world.createEntity();
    world.add(entity, trigger);
    world.add(entity, map.Scoped{});
    return entity;
}

pub fn spawnPointLight(world: *World, object: Object) Entity {
    const entity = world.createEntity();
    world.add(entity, light.Point{
        .radius = object.getProperty("radius", f32) orelse 96,
    });
    world.add(entity, object.position);
    world.add(entity, map.Scoped{});
    applyLight(world, entity, object);
    return entity;
}

pub fn spawnSpotLight(world: *World, object: Object) Entity {
    const entity = world.createEntity();
    const spot = object.getClass("spot").?;
    std.debug.assert(spot.is("Spotlight"));
    world.add(entity, light.Spot{
        .radius = spot.get("radius", f32).?,
        .direction = spotDirection(spot),
    });
    world.add(entity, object.position);
    world.add(entity, map.Scoped{});
    applyLight(world, entity, object);
    return entity;
}

fn spotDirection(spot: zhu.extend.tiled.ClassProperty) zhu.Vector2 {
    const degrees = spot.get("direction_deg", f32).?;
    const radians = std.math.degreesToRadians(degrees);
    return .xy(@cos(radians), @sin(radians));
}

// 根据 Tiled 属性设置灯光的昼夜可见性
fn applyLight(world: *World, entity: Entity, object: Object) void {
    const day = object.getProperty("day_only", bool) orelse false;
    const night = object.getProperty("night_only", bool) orelse !day;
    const dark = context.time.isDark();

    if (day) {
        world.add(entity, light.DayOnly{});
        if (dark) world.add(entity, light.Disabled{});
        return;
    }

    if (night) {
        world.add(entity, light.NightOnly{});
        if (!dark) world.add(entity, light.Disabled{});
    }
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
test "spawnPlayer 会创建玩家实体" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockFarmImages();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    spawnPlayer(&world, .xy(160, 96));

    const player = world.getIdentity(actor.Player).?;
    try expectEqual(160, world.get(player, component.Position).?.x);
    try expectEqual(1, world.raw(motion.Velocity).len);
    try expectEqual(1, world.raw(actor.Actor).len);
    try expectEqual(1, world.raw(render.Sprite).len);
    try expectEqual(1, world.raw(render.Render).len);
    try expectEqual(1, world.assure(render.YSort).dense.items.len);
}

test "spawnPlayer 重复调用只保留一个玩家" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockFarmImages();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    spawnPlayer(&world, .xy(160, 96));
    spawnPlayer(&world, .xy(200, 128));

    const player = world.getIdentity(actor.Player).?;
    try expectEqual(200, world.get(player, component.Position).?.x);
    try expectEqual(1, world.raw(component.Position).len);
    try expectEqual(1, world.raw(motion.Velocity).len);
    try expectEqual(1, world.raw(actor.Actor).len);
}

test "spawnAnimal 会创建可漫游动物实体" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockAnimalImages();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const entity = spawnAnimal(&world, .cow);
    world.add(entity, component.Position.xy(12, 34));
    world.getPtr(entity, actor.Wander).?.home = .xy(12, 34);

    try expectEqual(12, world.get(entity, component.Position).?.x);
    try expectEqual(actor.AnimalKind.cow, world.get(entity, actor.Animal).?.kind);
    try expectEqual(1, world.assure(actor.Npc).dense.items.len);
    try expectEqual(1, world.raw(actor.Wander).len);
    try expectEqual(1, world.raw(motion.Velocity).len);
    try expectEqual(1, world.raw(render.Sprite).len);
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
    try expectEqual(0, crop.timer);
}

test "地图摆件按底边定位生成实体" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();

    const imageId = 1234;
    const tileSetId = 5678;
    const image = zhu.graphics.Image{ .size = .xy(16, 16) };
    zhu.assets.putImage(imageId, image);

    const tiles = [_]tiled.Tile{
        .{
            .id = imageId,
            .objectGroup = null,
            .properties = &.{},
            .animation = &.{},
        },
    };
    const tileSets = [_]tiled.TileSet{
        .{
            .id = tileSetId,
            .columns = 0,
            .tileCount = 1,
            .image = imageId,
            .tileSize = .xy(16, 16),
            .tiles = &tiles,
        },
    };
    const refs = [_]tiled.TileSetRef{
        .{ .id = tileSetId, .firstGid = 1, .max = 2 },
    };
    const testMap = tiled.Map{
        .height = 1,
        .width = 1,
        .tileSize = .xy(16, 16),
        .layers = &.{},
        .tileSetRefs = &refs,
    };
    tiled.init(&tileSets);
    defer tiled.init(@import("zon/map/tile.zon"));

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const entity = spawnMapProp(&world, &testMap, .{
        .id = 1,
        .gid = 1,
        .name = "",
        .type = "",
        .position = .xy(12, 34),
        .size = .xy(20, 30),
        .point = false,
        .properties = &.{},
        .extend = .{},
    });

    const position = world.get(entity, component.Position).?;
    const sprite = world.get(entity, render.Sprite).?;

    try expectEqual(12, position.x);
    try expectEqual(34, position.y);
    try expectEqual(-30, sprite.offset.y);
    try expectEqual(20, sprite.size.?.x);
    try expectEqual(30, sprite.size.?.y);
}

test "地图摆件优先用碰撞底边作为排序点" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();

    const imageId = 1234;
    const tileSetId = 5678;
    const image = zhu.graphics.Image{ .size = .xy(20, 40) };
    zhu.assets.putImage(imageId, image);

    const collisions = [_]tiled.Object{.{
        .id = 1,
        .gid = 0,
        .name = "",
        .type = "",
        .position = .xy(2, 12),
        .size = .xy(16, 8),
        .point = false,
        .properties = &.{},
        .extend = .{},
    }};
    const tiles = [_]tiled.Tile{.{
        .id = imageId,
        .objectGroup = .{ .visible = true, .objects = &collisions },
        .properties = &.{},
        .animation = &.{},
    }};
    const tileSets = [_]tiled.TileSet{.{
        .id = tileSetId,
        .columns = 0,
        .tileCount = 1,
        .image = imageId,
        .tileSize = .xy(20, 40),
        .tiles = &tiles,
    }};
    const refs = [_]tiled.TileSetRef{
        .{ .id = tileSetId, .firstGid = 1, .max = 2 },
    };
    const testMap = tiled.Map{
        .height = 1,
        .width = 1,
        .tileSize = .xy(16, 16),
        .layers = &.{},
        .tileSetRefs = &refs,
    };
    tiled.init(&tileSets);
    defer tiled.init(@import("zon/map/tile.zon"));

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const entity = spawnMapProp(&world, &testMap, .{
        .id = 1,
        .gid = 1,
        .name = "",
        .type = "",
        .position = .xy(12, 50),
        .size = .xy(20, 40),
        .point = false,
        .properties = &.{},
        .extend = .{},
    });

    const position = world.get(entity, component.Position).?;
    const sprite = world.get(entity, render.Sprite).?;

    try expectEqual(12, position.x);
    try expectEqual(30, position.y);
    try expectEqual(-20, sprite.offset.y);
    try expectEqual(10, position.y + sprite.offset.y);
}

test "带 anim_id 的地图摆件会创建停止的非循环动画" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();

    const imageId = 1234;
    const tileSetId = 5678;
    const image = zhu.graphics.Image{ .size = .xy(32, 16) };
    zhu.assets.putImage(imageId, image);

    const frames = [_]zhu.graphics.Frame{
        .{ .offset = .xy(0, 0), .duration = 0.1 },
        .{ .offset = .xy(16, 0), .duration = 0.1 },
    };
    const properties = [_]tiled.Property{
        .{ .name = "anim_id", .value = .{ .string = "open" } },
    };
    const tiles = [_]tiled.Tile{
        .{
            .id = 0,
            .objectGroup = null,
            .properties = &properties,
            .animation = &frames,
        },
    };
    const tileSets = [_]tiled.TileSet{
        .{
            .id = tileSetId,
            .columns = 2,
            .tileCount = 2,
            .image = imageId,
            .tileSize = .xy(16, 16),
            .tiles = &tiles,
        },
    };
    const refs = [_]tiled.TileSetRef{
        .{ .id = tileSetId, .firstGid = 1, .max = 3 },
    };
    const testMap = tiled.Map{
        .height = 1,
        .width = 1,
        .tileSize = .xy(16, 16),
        .layers = &.{},
        .tileSetRefs = &refs,
    };
    tiled.init(&tileSets);
    defer tiled.init(@import("zon/map/tile.zon"));

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const entity = spawnMapProp(&world, &testMap, .{
        .id = 1,
        .gid = 1,
        .name = "",
        .type = "",
        .position = .xy(12, 34),
        .size = .zero,
        .point = false,
        .properties = &.{},
        .extend = .{},
    });

    const animation = world.get(entity, actor.Animation).?;
    const sprite = world.get(entity, render.Sprite).?;

    try std.testing.expect(!animation.loop);
    try std.testing.expect(animation.isFinished());
    try expectEqual(0, sprite.image.offset.x);
    try expectEqual(0, sprite.image.offset.y);
}

test "spawnPointLight 创建地图作用域点光" {
    context.time.reset();
    defer context.time.reset();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const entity = spawnPointLight(&world, .{
        .id = 1,
        .gid = 0,
        .name = "point",
        .type = "light",
        .position = .xy(10, 20),
        .size = .zero,
        .point = true,
        .properties = &.{
            .{ .name = "radius", .value = .{ .float = 64 } },
        },
        .extend = .{},
    });

    try expectEqual(10, world.get(entity, component.Position).?.x);
    try expectEqual(64, world.get(entity, light.Point).?.radius);
    try std.testing.expect(world.has(entity, map.Scoped));
}

test "spawnSpotLight 创建地图作用域聚光" {
    context.time.reset();
    defer context.time.reset();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const entity = spawnSpotLight(&world, .{
        .id = 1,
        .gid = 0,
        .name = "spot",
        .type = "light",
        .position = .xy(10, 20),
        .size = .zero,
        .point = true,
        .properties = &.{
            .{ .name = "spot", .value = .{ .class = .{
                .type = "Spotlight",
                .properties = &.{
                    .{ .name = "direction_deg", .value = .{ .float = 90 } },
                    .{ .name = "radius", .value = .{ .float = 96 } },
                },
            } } },
        },
        .extend = .{},
    });

    try expectEqual(20, world.get(entity, component.Position).?.y);
    try expectEqual(96, world.get(entity, light.Spot).?.radius);
    try std.testing.expect(world.has(entity, map.Scoped));
}

test "白天加载 night-only 点光会禁用" {
    context.time.reset();
    defer context.time.reset();
    context.time.hour = 12;
    context.time.minute = 0;

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    _ = spawnPointLight(&world, .{
        .id = 1,
        .gid = 0,
        .name = "point",
        .type = "light",
        .position = .xy(10, 20),
        .size = .zero,
        .point = true,
        .properties = &.{
            .{ .name = "night_only", .value = .{ .bool = true } },
            .{ .name = "radius", .value = .{ .float = 64 } },
        },
        .extend = .{},
    });

    var query = world.query(.{
        component.Position,
        light.Point,
        light.NightOnly,
        light.Disabled,
    });
    const e = query.next().?;

    try expectEqual(10, query.get(e, component.Position).x);
    try expectEqual(64, query.get(e, light.Point).radius);
    try std.testing.expectEqual(null, query.next());
}

test "夜晚加载 night-only 点光会启用" {
    context.time.reset();
    defer context.time.reset();
    context.time.hour = 19;
    context.time.minute = 0;

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const entity = spawnPointLight(&world, .{
        .id = 1,
        .gid = 0,
        .name = "point",
        .type = "light",
        .position = .xy(10, 20),
        .size = .zero,
        .point = true,
        .properties = &.{
            .{ .name = "night_only", .value = .{ .bool = true } },
            .{ .name = "radius", .value = .{ .float = 64 } },
        },
        .extend = .{},
    });

    var query = world.queryNone(.{
        component.Position,
        light.Point,
        light.NightOnly,
    }, .{light.Disabled});
    const e = query.next().?;

    try expectEqual(20, query.get(e, component.Position).y);
    try std.testing.expectEqual(null, query.next());
    _ = entity;
}

test "day-only 点光白天启用夜晚禁用" {
    context.time.reset();
    defer context.time.reset();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const dayOnly = [_]zhu.extend.tiled.Property{
        .{ .name = "day_only", .value = .{ .bool = true } },
    };

    context.time.hour = 12;
    _ = spawnPointLight(&world, .{
        .id = 1,
        .gid = 0,
        .name = "point",
        .type = "light",
        .position = .xy(10, 20),
        .size = .zero,
        .point = true,
        .properties = &dayOnly,
        .extend = .{},
    });

    context.time.hour = 19;
    _ = spawnPointLight(&world, .{
        .id = 2,
        .gid = 0,
        .name = "point",
        .type = "light",
        .position = .xy(30, 40),
        .size = .zero,
        .point = true,
        .properties = &dayOnly,
        .extend = .{},
    });

    var enabled = world.queryNone(.{
        component.Position,
        light.Point,
        light.DayOnly,
    }, .{light.Disabled});
    const first = enabled.next().?;
    try expectEqual(10, enabled.get(first, component.Position).x);
    try std.testing.expectEqual(null, enabled.next());

    var disabled = world.query(.{
        component.Position,
        light.Point,
        light.DayOnly,
        light.Disabled,
    });
    const second = disabled.next().?;
    try expectEqual(30, disabled.get(second, component.Position).x);
    try std.testing.expectEqual(null, disabled.next());
}

fn putMockFarmImages() void {
    const image = zhu.graphics.Image{ .size = .xy(256, 256) };

    for (prefab.actor.player.animations) |animation| {
        zhu.assets.putImage(animation.imageId, image);
    }
}

fn putMockCropImages() void {
    const image = zhu.graphics.Image{ .size = .xy(256, 256) };
    for (prefab.farm.crop.stages) |stage| {
        zhu.assets.putImage(stage.sprite.imageId, image);
    }
}

fn putMockAnimalImages() void {
    const image = zhu.graphics.Image{ .size = .xy(128, 288) };
    for (prefab.farm.animals) |animalConfig| {
        zhu.assets.putImage(animalConfig.sprite.imageId, image);
    }
}
