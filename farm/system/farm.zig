const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const factory = @import("../factory.zig");
const inventory = @import("../inventory.zig");
const map = @import("../map.zig");

const Player = component.actor.Player;
const UseFrame = component.actor.UseFrame;
const WantUse = component.actor.WantUse;
const Crop = component.farm.Crop;
const CropEnum = component.farm.CropEnum;
const Ground = component.farm.Ground;
const ItemEnum = component.item.ItemEnum;
const Pickup = component.item.Pickup;
const event = component.event;
const World = zhu.ecs.World;

pub fn update(world: *World) void {
    const player = world.getIdentity(Player).?;
    if (!world.has(player, UseFrame)) return;

    const want = world.get(player, WantUse).?;
    useItem(world, want);

    // 一次动作只结算一次，结算后清理关键帧标记和意图。
    world.remove(player, UseFrame);
    world.remove(player, WantUse);
}

fn useItem(world: *World, want: WantUse) void {
    // WantUse.item 是点击瞬间锁定的物品，不读取当前快捷栏状态。
    switch (want.item) {
        .hoe => if (map.land.hoe(want.target)) {
            world.addEvent(event.SoundPlay{ .id = .hoe });
        },
        .water => waterTarget(world, want.target),
        .sickle => harvestTarget(world, want.target),
        .strawberrySeed => useSeed(world, want, .strawberry),
        .potatoSeed => useSeed(world, want, .potato),
        .pickaxe, .axe => unreachable,
        .strawberry, .potato => unreachable,
    }
}

fn harvestTarget(world: *World, position: zhu.Vector2) void {
    const tile = map.land.getTile(position) orelse return;
    const entity = tile.crop() orelse return;
    const crop = world.get(entity, Crop).?;
    if (crop.stage != .mature) return;

    // 成熟作物先从地块移除，再生成一个可拾取产物。
    const item = factory.harvestItem(crop.kind);
    world.destroyEntity(entity);
    tile.object = null;
    factory.spawnPickup(world, .{
        .item = item,
        .origin = position.add(map.data.tileSize.scale(0.5)),
    });
    world.addEvent(event.SoundPlay{ .id = .harvest });
}

fn useSeed(world: *World, want: WantUse, kind: CropEnum) void {
    if (!map.land.canPlant(want.target)) return;
    if (!inventory.use(want.item, 1)) return;

    const tile = map.land.getTile(want.target).?;
    const crop = factory.spawnCrop(world, want.target, kind);
    tile.object = .{ .entity = crop };
    world.addEvent(event.SoundPlay{ .id = .plant });
}

fn waterTarget(world: *World, position: zhu.Vector2) void {
    if (!map.land.water(position)) return;

    const tile = map.land.getTile(position) orelse return;
    if (tile.crop()) |entity| {
        if (world.getPtr(entity, Crop)) |crop| crop.watered = true;
    }
    world.addEvent(event.SoundPlay{ .id = .water });
}

const testTarget = zhu.Vector2.xy(32, 48);

fn setActiveItem(item: ItemEnum, count: u32) void {
    inventory.reset();
    _ = inventory.add(item, count);
}

fn putMockImages() void {
    const image = zhu.Image{ .size = .xy(256, 256) };
    for (factory.zon.crops) |cropConfig| {
        for (cropConfig.stages) |stage| {
            zhu.assets.putImage(stage.sprite.imageId, image);
        }
    }
    for (factory.zon.items) |item| {
        zhu.assets.putImage(item.icon.imageId, image);
    }
}

fn enterTestLand() void {
    map.spatial.enter(&map.maps[0]);
    map.land.enter(&map.maps[0]);
    map.spatial.tiles[map.maps[0].worldToTileIndex(testTarget).?]
        .insert(.arable);
}

fn exitTestLand() void {
    map.land.exit();
    map.spatial.exit();
}

test "toolHit 会按 WantUse 锄地" {
    zhu.assets.allocator = std.testing.allocator;
    enterTestLand();
    defer exitTestLand();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.add(player, WantUse{ .item = .hoe, .target = testTarget });
    world.add(player, UseFrame{});

    update(&world);

    try std.testing.expectEqual(Ground.dry, map.land.getTile(testTarget).?.ground.?);
    try std.testing.expect(!world.has(player, WantUse));

    const sounds = world.getEvent(event.SoundPlay);
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.hoe, sounds[0].id);
}

test "非事件帧不会结算 WantUse" {
    zhu.assets.allocator = std.testing.allocator;
    enterTestLand();
    defer exitTestLand();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.add(player, WantUse{ .item = .hoe, .target = testTarget });

    update(&world);

    try std.testing.expectEqual(null, map.land.getTile(testTarget).?.ground);
    try std.testing.expect(world.has(player, WantUse));
}

test "seedPlant 会种植并扣种子" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockImages();
    enterTestLand();
    defer exitTestLand();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    setActiveItem(.strawberrySeed, 2);
    try std.testing.expect(map.land.hoe(testTarget));

    const player = world.createIdentity(Player);
    world.add(player, WantUse{
        .item = .strawberrySeed,
        .target = testTarget,
    });
    world.add(player, UseFrame{});

    update(&world);

    const index = inventory.bar.refs[inventory.bar.active].?;
    try std.testing.expectEqual(1, inventory.store.stacks[index].count);

    const cropEntity = map.land.getTile(testTarget).?.crop().?;
    try std.testing.expectEqual(
        CropEnum.strawberry,
        world.get(cropEntity, Crop).?.kind,
    );

    const sounds = world.getEvent(event.SoundPlay);
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.plant, sounds[0].id);
}

test "seedPlant 使用最后一颗种子后快捷栏无物品" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockImages();
    enterTestLand();
    defer exitTestLand();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    setActiveItem(.potatoSeed, 1);
    try std.testing.expect(map.land.hoe(testTarget));

    const player = world.createIdentity(Player);
    world.add(player, WantUse{ .item = .potatoSeed, .target = testTarget });
    world.add(player, UseFrame{});

    update(&world);

    const index = inventory.bar.refs[inventory.bar.active].?;
    try std.testing.expectEqual(0, inventory.store.stacks[index].count);
    try std.testing.expectEqual(null, inventory.activeItem());
    try std.testing.expect(map.land.getTile(testTarget).?.crop() != null);
}

test "seedPlant 没有种子时不会种植" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockImages();
    enterTestLand();
    defer exitTestLand();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    inventory.reset();
    try std.testing.expect(map.land.hoe(testTarget));

    const player = world.createIdentity(Player);
    world.add(player, WantUse{
        .item = .strawberrySeed,
        .target = testTarget,
    });
    world.add(player, UseFrame{});

    update(&world);

    try std.testing.expectEqual(null, map.land.getTile(testTarget).?.object);
    try std.testing.expectEqual(0, world.getEvent(event.SoundPlay).len);
}

test "seedPlant 无耕地时不扣种子" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockImages();
    enterTestLand();
    defer exitTestLand();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    setActiveItem(.strawberrySeed, 2);

    const player = world.createIdentity(Player);
    world.add(player, WantUse{
        .item = .strawberrySeed,
        .target = testTarget,
    });
    world.add(player, UseFrame{});

    update(&world);

    const index = inventory.bar.refs[inventory.bar.active].?;
    try std.testing.expectEqual(2, inventory.store.stacks[index].count);
    try std.testing.expectEqual(null, map.land.getTile(testTarget).?.object);
    try std.testing.expectEqual(0, world.getEvent(event.SoundPlay).len);
}

test "seedPlant 已有作物时不扣种子" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockImages();
    enterTestLand();
    defer exitTestLand();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    setActiveItem(.strawberrySeed, 2);
    try std.testing.expect(map.land.hoe(testTarget));
    const oldCrop = world.createEntity();
    world.add(oldCrop, Crop{ .kind = .potato });
    map.land.getTile(testTarget).?.object = .{ .entity = oldCrop };

    const player = world.createIdentity(Player);
    world.add(player, WantUse{
        .item = .strawberrySeed,
        .target = testTarget,
    });
    world.add(player, UseFrame{});

    update(&world);

    const index = inventory.bar.refs[inventory.bar.active].?;
    try std.testing.expectEqual(2, inventory.store.stacks[index].count);
    try std.testing.expectEqual(oldCrop, map.land.getTile(testTarget).?.crop().?);
    try std.testing.expectEqual(0, world.getEvent(event.SoundPlay).len);
}

test "toolHit 会浇水并标记作物" {
    zhu.assets.allocator = std.testing.allocator;
    enterTestLand();
    defer exitTestLand();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    try std.testing.expect(map.land.hoe(testTarget));
    const crop = world.createEntity();
    world.add(crop, Crop{});
    map.land.getTile(testTarget).?.object = .{ .entity = crop };

    const player = world.createIdentity(Player);
    world.add(player, WantUse{ .item = .water, .target = testTarget });
    world.add(player, UseFrame{});

    update(&world);

    const tile = map.land.getTile(testTarget).?;
    try std.testing.expectEqual(Ground.wet, tile.ground.?);
    try std.testing.expect(world.get(crop, Crop).?.watered);

    const sounds = world.getEvent(event.SoundPlay);
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.water, sounds[0].id);
}

test "sickle 会收获成熟作物并生成掉落物" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockImages();
    enterTestLand();
    defer exitTestLand();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    try std.testing.expect(map.land.hoe(testTarget));
    const crop = world.createEntity();
    world.add(crop, Crop{ .stage = .mature, .kind = .potato });
    map.land.getTile(testTarget).?.object = .{ .entity = crop };

    const player = world.createIdentity(Player);
    world.add(player, WantUse{ .item = .sickle, .target = testTarget });
    world.add(player, UseFrame{});

    update(&world);

    try std.testing.expectEqual(null, map.land.getTile(testTarget).?.object);
    try std.testing.expectEqual(null, world.get(crop, Crop));

    const pickups = world.values(Pickup);
    try std.testing.expectEqual(1, pickups.len);
    try std.testing.expectEqual(ItemEnum.potato, pickups[0].item);

    const sounds = world.getEvent(event.SoundPlay);
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.harvest, sounds[0].id);
}

test "hoe 不会收获成熟作物" {
    zhu.assets.allocator = std.testing.allocator;
    enterTestLand();
    defer exitTestLand();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    try std.testing.expect(map.land.hoe(testTarget));
    const crop = world.createEntity();
    world.add(crop, Crop{ .stage = .mature, .kind = .potato });
    map.land.getTile(testTarget).?.object = .{ .entity = crop };

    const player = world.createIdentity(Player);
    world.add(player, WantUse{ .item = .hoe, .target = testTarget });
    world.add(player, UseFrame{});

    update(&world);

    try std.testing.expectEqual(crop, map.land.getTile(testTarget).?.crop().?);
    try std.testing.expectEqual(0, world.values(Pickup).len);
    try std.testing.expectEqual(0, world.getEvent(event.SoundPlay).len);
}
