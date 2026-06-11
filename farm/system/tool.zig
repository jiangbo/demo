const std = @import("std");
const zhu = @import("zhu");

const factory = @import("../factory.zig");
const component = @import("../component.zig");
const context = @import("../context.zig");
const toolbar = @import("../ui/toolbar.zig");
const land = @import("../map.zig").land;

const Crop = component.farm.Crop;
const Player = component.actor.Player;
const Target = component.ui.Target;
const event = component.event;

pub fn update(world: *zhu.ecs.World) void {
    if (!context.input.mousePressed(.LEFT)) return;

    const player = world.getIdentity(Player).?;
    const target = world.get(player, Target).?;
    if (!target.active) return;

    const tile = land.getTile(target.position) orelse return;

    if (tile.crop()) |entity| {
        const crop = world.get(entity, Crop) orelse return;
        if (crop.stage != .mature) return;

        // 按作物种类决定产出物品
        const pickupItem = factory.harvestItem(crop.kind);
        world.destroyEntity(entity);
        tile.object = null;
        const pickupEntity = factory.spawnPickup(world, pickupItem);
        world.add(pickupEntity, target.position);
        world.addEvent(event.SoundPlay{ .id = .harvest });
        return;
    }

    if (toolbar.active()) |tool| {
        // 如果当前工具是某种种子，从 ItemEnum 反推 CropEnum 再种植
        if (factory.asSeed(tool.type)) |kind| {
            if (plant(world, target.position, kind)) {
                world.addEvent(event.SoundPlay{ .id = .plant });
            }
            return;
        }
        switch (tool.type) {
            .hoe => if (land.hoe(target.position)) {
                world.addEvent(event.SoundPlay{ .id = .hoe });
            },
            .water => if (waterTarget(world, target.position)) {
                world.addEvent(event.SoundPlay{ .id = .water });
            },
            // 产出类和工具类在手上不做操作
            else => {},
        }
    }
}

fn waterTarget(world: *zhu.ecs.World, position: zhu.Vector2) bool {
    if (!land.water(position)) return false;

    const tile = land.getTile(position) orelse return false;
    if (tile.crop()) |entity| {
        if (world.getPtr(entity, Crop)) |crop| {
            crop.watered = true;
        }
    }
    return true;
}

fn plant(world: *zhu.ecs.World, position: zhu.Vector2, kind: component.farm.CropEnum) bool {
    const tile = land.getTile(position) orelse return false;
    if (tile.ground == null or tile.object != null) return false;

    toolbar.active().?.count -= 1;
    // 用从种子反推得到的 kind 创建作物实体
    const entity = factory.spawnCrop(world, position, kind);
    tile.object = .{ .entity = entity };
    return true;
}

const testMaps = [_]zhu.extend.tiled.Map{@import("../zon/map/school.zon")};
const testTarget = zhu.Vector2.xy(32, 48);

fn resetMouse() void {
    zhu.input.reset();
}

fn clickMouse() void {
    resetMouse();
    var ev = zhu.window.Event{
        .type = .MOUSE_DOWN,
        .mouse_button = .LEFT,
    };
    zhu.input.handle(&ev);
}

fn setActiveItem(item: component.item.ItemEnum, count: u32) void {
    toolbar.slots = @splat(.{ .type = .hoe, .count = 0 });
    toolbar.slotIndex = 0;
    toolbar.slots[0] = .{ .type = item, .count = count };
}

fn addPlayerTarget(world: *zhu.ecs.World, position: zhu.Vector2) void {
    const player = world.createIdentity(Player);
    world.add(player, Target{
        .position = position,
        .active = true,
    });
}

fn putMockImages() void {
    const image = zhu.Image{ .size = .xy(256, 256) };
    // 遍历所有作物种类的所有阶段
    for (factory.zon.crops) |cropConfig| {
        for (cropConfig.stages) |stage| {
            zhu.assets.putImage(stage.sprite.imageId, image);
        }
    }
    for (factory.zon.items) |it| {
        zhu.assets.putImage(it.icon.imageId, image);
    }
}

test "tool update 有效锄地会发出 hoe 音效" {
    zhu.assets.allocator = std.testing.allocator;
    land.enter(&testMaps[0]);
    defer land.exit();
    resetMouse();
    defer resetMouse();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    addPlayerTarget(&world, testTarget);
    setActiveItem(.hoe, 1);
    clickMouse();

    update(&world);

    const sounds = world.getEvent(event.SoundPlay).items;
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.hoe, sounds[0].id);
}

test "tool update 无效浇水不会发出音效" {
    zhu.assets.allocator = std.testing.allocator;
    land.enter(&testMaps[0]);
    defer land.exit();
    resetMouse();
    defer resetMouse();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    addPlayerTarget(&world, testTarget);
    setActiveItem(.water, 1);
    clickMouse();

    update(&world);

    try std.testing.expectEqual(0, world.getEvent(event.SoundPlay).items.len);
}

test "tool update 有效浇水会发出 water 音效" {
    zhu.assets.allocator = std.testing.allocator;
    land.enter(&testMaps[0]);
    defer land.exit();
    resetMouse();
    defer resetMouse();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    addPlayerTarget(&world, testTarget);
    setActiveItem(.water, 1);
    try std.testing.expect(land.hoe(testTarget));
    clickMouse();

    update(&world);

    const sounds = world.getEvent(event.SoundPlay).items;
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.water, sounds[0].id);
}

test "tool update 种植 strawberrySeed 会发出 plant 音效且作物 kind 正确" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockImages();
    land.enter(&testMaps[0]);
    defer land.exit();
    resetMouse();
    defer resetMouse();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    addPlayerTarget(&world, testTarget);
    setActiveItem(.strawberrySeed, 2);
    try std.testing.expect(land.hoe(testTarget));
    clickMouse();

    update(&world);

    const sounds = world.getEvent(event.SoundPlay).items;
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.plant, sounds[0].id);
    try std.testing.expectEqual(1, toolbar.slots[0].count);
    const cropEntity = land.getTile(testTarget).?.crop();
    try std.testing.expect(cropEntity != null);
    try std.testing.expectEqual(
        component.farm.CropEnum.strawberry,
        world.get(cropEntity.?, Crop).?.kind,
    );
}

test "tool update 种植 potatoSeed 会创建 potato 作物" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockImages();
    land.enter(&testMaps[0]);
    defer land.exit();
    resetMouse();
    defer resetMouse();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    addPlayerTarget(&world, testTarget);
    setActiveItem(.potatoSeed, 2);
    try std.testing.expect(land.hoe(testTarget));
    clickMouse();

    update(&world);

    const sounds = world.getEvent(event.SoundPlay).items;
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.plant, sounds[0].id);
    const cropEntity = land.getTile(testTarget).?.crop();
    try std.testing.expect(cropEntity != null);
    try std.testing.expectEqual(
        component.farm.CropEnum.potato,
        world.get(cropEntity.?, Crop).?.kind,
    );
}

test "tool update 收获成熟 strawberry 会产出 strawberry 物品" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockImages();
    land.enter(&testMaps[0]);
    defer land.exit();
    resetMouse();
    defer resetMouse();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    addPlayerTarget(&world, testTarget);
    const crop = world.createEntity();
    world.add(crop, Crop{ .stage = .mature, .kind = .strawberry });
    land.getTile(testTarget).?.object = .{ .entity = crop };
    clickMouse();

    update(&world);

    const sounds = world.getEvent(event.SoundPlay).items;
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.harvest, sounds[0].id);
    try std.testing.expectEqual(null, land.getTile(testTarget).?.crop());
    // 拾取物应是 strawberry 类型
    var pickups = world.query(.{component.item.Pickup});
    const pe = pickups.next().?;
    try std.testing.expectEqual(
        component.item.ItemEnum.strawberry,
        pickups.get(pe, component.item.Pickup).item,
    );
}

test "tool update 收获成熟 potato 会产出 potato 物品" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockImages();
    land.enter(&testMaps[0]);
    defer land.exit();
    resetMouse();
    defer resetMouse();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    addPlayerTarget(&world, testTarget);
    const crop = world.createEntity();
    world.add(crop, Crop{ .stage = .mature, .kind = .potato });
    land.getTile(testTarget).?.object = .{ .entity = crop };
    clickMouse();

    update(&world);

    const sounds = world.getEvent(event.SoundPlay).items;
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.harvest, sounds[0].id);
    // 拾取物应是 potato 类型
    var pickups = world.query(.{component.item.Pickup});
    const pe = pickups.next().?;
    try std.testing.expectEqual(
        component.item.ItemEnum.potato,
        pickups.get(pe, component.item.Pickup).item,
    );
}
