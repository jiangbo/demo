const std = @import("std");
const zhu = @import("zhu");

const factory = @import("../factory.zig");
const component = @import("../component.zig");
const prefab = @import("../prefab.zig");
const toolbar = @import("../ui/toolbar.zig");
const land = @import("../map.zig").land;

const Crop = component.farm.Crop;
const Player = component.actor.Player;
const Target = component.ui.Target;
const event = component.event;

pub fn update(world: *zhu.ecs.World) void {
    if (!zhu.window.mouse.pressed(.LEFT)) return;

    const player = world.getIdentity(Player).?;
    const target = world.get(player, Target).?;
    if (!target.active) return;

    const tile = land.getTile(target.position) orelse return;

    if (tile.crop) |entity| {
        const crop = world.get(entity, Crop) orelse return;
        if (crop.stage != .mature) return;

        world.destroyEntity(entity);
        tile.crop = null;
        const pickupEntity = factory.spawnPickup(world, .crop);
        world.add(pickupEntity, target.position);
        world.addEvent(event.SoundPlay{ .id = .harvest });
        return;
    }

    if (toolbar.active()) |tool| {
        switch (tool.type) {
            .hoe => if (land.hoe(target.position)) {
                world.addEvent(event.SoundPlay{ .id = .hoe });
            },
            .water => if (waterTarget(world, target.position)) {
                world.addEvent(event.SoundPlay{ .id = .water });
            },
            .seed => if (plant(world, target.position)) {
                world.addEvent(event.SoundPlay{ .id = .plant });
            },
            .crop => {},
        }
    }
}

fn waterTarget(world: *zhu.ecs.World, position: zhu.Vector2) bool {
    if (!land.water(position)) return false;

    const tile = land.getTile(position) orelse return false;
    if (tile.crop) |entity| {
        if (world.getPtr(entity, Crop)) |crop| {
            crop.watered = true;
        }
    }
    return true;
}

fn plant(world: *zhu.ecs.World, position: zhu.Vector2) bool {
    const tile = land.getTile(position) orelse return false;
    if (tile.land == null or tile.crop != null) return false;

    toolbar.active().?.count -= 1;
    const entity = factory.spawnCrop(world, position);
    tile.crop = entity;
    return true;
}

const testMaps = [_]zhu.extend.tiled.Map{@import("../zon/school.zon")};
const testTarget = zhu.Vector2.xy(32, 48);

fn resetMouse() void {
    zhu.window.mouse.state = .initEmpty();
    zhu.window.mouse.lastState = .initEmpty();
}

fn clickMouse() void {
    resetMouse();
    const leftMouseButton = 0;
    zhu.window.mouse.state.set(leftMouseButton);
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
    for (prefab.farm.crop.stages) |stage| {
        zhu.assets.putImage(stage.sprite.imageId, image);
    }
    for (prefab.farm.items) |item| {
        zhu.assets.putImage(item.icon.imageId, image);
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

test "tool update 种植成功会发出 plant 音效" {
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
    setActiveItem(.seed, 2);
    try std.testing.expect(land.hoe(testTarget));
    clickMouse();

    update(&world);

    const sounds = world.getEvent(event.SoundPlay).items;
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.plant, sounds[0].id);
    try std.testing.expectEqual(1, toolbar.slots[0].count);
    try std.testing.expect(land.getTile(testTarget).?.crop != null);
}

test "tool update 收获成熟作物会发出 harvest 音效" {
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
    world.add(crop, Crop{ .stage = .mature });
    land.getTile(testTarget).?.crop = crop;
    clickMouse();

    update(&world);

    const sounds = world.getEvent(event.SoundPlay).items;
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.harvest, sounds[0].id);
    try std.testing.expectEqual(null, land.getTile(testTarget).?.crop);
}
