const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const context = @import("../context.zig");
const factory = @import("../factory.zig");
const inventory = @import("../inventory.zig");
const map = @import("../map.zig");

const Actor = component.actor.Actor;
const Facing = component.actor.Facing;
const Player = component.actor.Player;
const Action = component.actor.Action;
const Busy = component.actor.Busy;
const Position = component.Position;
const Target = component.ui.Target;
const Velocity = component.motion.Velocity;
const Crop = component.farm.Crop;
const CropEnum = component.farm.CropEnum;
const Ground = component.farm.Ground;
const ItemEnum = component.item.ItemEnum;
const Pickup = component.item.Pickup;
const event = component.event;
const World = zhu.ecs.World;
const Entity = zhu.ecs.Entity;

const playerSpeed: f32 = 60;
const tileRange: i32 = 1;

pub fn update(world: *World) void {
    const player = world.getIdentity(Player).?;

    // 工具动作播放期间不接收新的移动和工具输入。
    if (world.has(player, Busy)) return;

    updateTargetAction(world, player);
    updateMovement(world, player);
}

pub fn draw(world: *World) void {
    const player = world.getIdentity(Player).?;
    const target = world.get(player, Target).?;
    if (!target.active) return;

    const rect = zhu.Rect.init(target.position, map.data.tileSize);
    zhu.batch.drawRect(rect, .{ .color = target.color });
}

fn updateMovement(world: *World, player: Entity) void {
    if (world.has(player, Busy)) return;

    const direction = readDirection();
    const velocity = direction.scale(playerSpeed);
    world.getPtr(player, Velocity).?.value = velocity;

    const actor = world.getPtr(player, Actor).?;
    if (direction.length2() == 0) {
        actor.action = Action.idle;
        return;
    }

    actor.action = Action.walk;
    actor.facing = facingFromDirection(direction);
}

fn readDirection() zhu.Vector2 {
    var direction: zhu.Vector2 = .zero;
    if (context.input.held(.moveLeft)) direction.x -= 1;
    if (context.input.held(.moveRight)) direction.x += 1;
    if (context.input.held(.moveUp)) direction.y -= 1;
    if (context.input.held(.moveDown)) direction.y += 1;

    if (direction.length2() > 1) return direction.normalize();
    return direction;
}

fn targetPosition(world: *World, player: Entity) ?zhu.Vector2 {
    if (context.input.mouseCaptured) return null;

    const playerPos = world.get(player, Position).?;
    const playerTile = map.data.worldToTilePosition(playerPos);
    const mouseWorld = zhu.camera.toWorld(zhu.window.mouse);
    const mouseTile = map.data.worldToTilePosition(mouseWorld);

    if (map.data.tilePositionToIndex(mouseTile) == null) return null;

    const outOfRangeX = @abs(mouseTile.x - playerTile.x) > tileRange;
    const outOfRangeY = @abs(mouseTile.y - playerTile.y) > tileRange;
    if (outOfRangeX or outOfRangeY) return null;

    return map.data.tilePositionToWorld(mouseTile);
}

fn updateTargetAction(world: *World, player: Entity) void {
    const target = world.getPtr(player, Target).?;
    target.active = false;

    const item = inventory.activeItem() orelse return;
    if (!isTargetItem(item.item)) return;

    const position = targetPosition(world, player) orelse return;

    target.position = position;
    target.active = true;

    if (!context.input.mousePressed(.LEFT)) return;
    const actor = world.getPtr(player, Actor).?;
    const playerPos = world.get(player, Position).?;
    // 朝向按点击位置计算，目标格只负责工具结算。
    const mouseWorld = zhu.camera.toWorld(zhu.window.mouse);
    const direction = mouseWorld.sub(playerPos);
    if (!direction.approxEqual(.zero)) {
        actor.facing = facingFromDirection(direction);
    }

    actor.action = actionFromItem(item.item);
    world.getPtr(player, Velocity).?.value = .zero;
    world.add(player, Busy{});
    applyTool(world, position, item.item);
}

fn isTargetItem(item: ItemEnum) bool {
    return switch (item) {
        .hoe, .water, .strawberrySeed, .potatoSeed => true,
        .strawberry, .potato => false,
    };
}

fn actionFromItem(item: ItemEnum) Action {
    if (factory.asSeed(item) != null) return .planting;
    return switch (item) {
        .hoe => .hoe,
        .water => .watering,
        .strawberrySeed, .potatoSeed => unreachable,
        .strawberry, .potato => unreachable,
    };
}

fn applyTool(world: *World, position: zhu.Vector2, item: ItemEnum) void {
    const tile = map.land.getTile(position) orelse return;

    if (tile.crop()) |entity| {
        const crop = world.get(entity, Crop) orelse return;
        if (crop.stage == .mature) {
            const pickupItem = factory.harvestItem(crop.kind);
            world.destroyEntity(entity);
            tile.object = null;
            factory.spawnPickup(world, .{
                .item = pickupItem,
                .origin = position.add(map.data.tileSize.scale(0.5)),
            });
            world.addEvent(event.SoundPlay{ .id = .harvest });
            return;
        }
    }

    if (factory.asSeed(item)) |kind| {
        if (plant(world, position, kind)) {
            world.addEvent(event.SoundPlay{ .id = .plant });
        }
        return;
    }

    switch (item) {
        .hoe => if (map.land.hoe(position)) {
            world.addEvent(event.SoundPlay{ .id = .hoe });
        },
        .water => if (waterTarget(world, position)) {
            world.addEvent(event.SoundPlay{ .id = .water });
        },
        .strawberry, .potato => unreachable,
        .strawberrySeed, .potatoSeed => unreachable,
    }
}

fn waterTarget(world: *World, position: zhu.Vector2) bool {
    if (!map.land.water(position)) return false;

    const tile = map.land.getTile(position) orelse return false;
    if (tile.crop()) |entity| {
        if (world.getPtr(entity, Crop)) |crop| crop.watered = true;
    }
    return true;
}

fn plant(world: *World, position: zhu.Vector2, kind: CropEnum) bool {
    const tile = map.land.getTile(position) orelse return false;
    if (tile.ground == null or tile.object != null) return false;

    inventory.activeItem().?.count -= 1;
    const entity = factory.spawnCrop(world, position, kind);
    tile.object = .{ .entity = entity };
    return true;
}

fn facingFromDirection(direction: zhu.Vector2) Facing {
    if (@abs(direction.x) > @abs(direction.y)) {
        return if (direction.x < 0) .left else .right;
    }
    return if (direction.y < 0) .up else .down;
}

fn setKey(keyCode: zhu.key.Code) void {
    var ev = zhu.window.Event{
        .type = .KEY_DOWN,
        .key_code = keyCode,
    };
    zhu.input.handle(&ev);
}

fn clickMouse(button: zhu.mouse.Button) void {
    var ev = zhu.window.Event{
        .type = .MOUSE_DOWN,
        .mouse_button = button,
    };
    zhu.input.handle(&ev);
}

fn setActiveItem(item: ItemEnum, count: u32) void {
    inventory.reset();
    _ = inventory.add(item, count);
}

fn addTestPlayer(world: *World, position: zhu.Vector2) Entity {
    const player = world.createIdentity(Player);
    world.add(player, position);
    world.add(player, Velocity{});
    world.add(player, Actor{});
    world.add(player, Target{});
    return player;
}

const testTarget = zhu.Vector2.xy(32, 48);

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

test "玩家控制会把方向键写入速度" {
    zhu.input.reset();
    defer zhu.input.reset();
    context.init();
    defer context.init();

    setKey(.D);
    setKey(.W);

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const player = addTestPlayer(&world, .xy(24, 40));
    setActiveItem(.strawberry, 1);

    update(&world);

    const velocity = world.get(player, Velocity).?;
    try std.testing.expect(velocity.value.x > 0);
    try std.testing.expect(velocity.value.y < 0);
    const speed = velocity.value.length();
    try std.testing.expectApproxEqAbs(playerSpeed, speed, 0.01);

    const actor = world.get(player, Actor).?;
    try std.testing.expectEqual(Action.walk, actor.action);
    try std.testing.expectEqual(Facing.up, actor.facing);
}

test "忙碌状态会跳过输入并保持动作" {
    zhu.input.reset();
    defer zhu.input.reset();
    context.init();
    defer context.init();

    setKey(.D);

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const player = addTestPlayer(&world, .xy(24, 40));
    world.getPtr(player, Actor).?.action = .hoe;
    world.add(player, Busy{});

    update(&world);

    const velocity = world.get(player, Velocity).?;
    try std.testing.expect(velocity.value.approxEqual(.zero));
    try std.testing.expectEqual(Action.hoe, world.get(player, Actor).?.action);
}

test "目标框只在工具或种子选中时显示" {
    zhu.input.reset();
    defer zhu.input.reset();
    context.init();
    defer context.init();

    zhu.camera.init(.xy(640, 360));
    zhu.window.mouse = .xy(32, 48);

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const player = addTestPlayer(&world, .xy(24, 40));
    setActiveItem(.strawberry, 1);

    update(&world);
    try std.testing.expect(!world.get(player, Target).?.active);

    setActiveItem(.hoe, 1);
    update(&world);
    try std.testing.expect(world.get(player, Target).?.active);
}

test "点击目标会进入忙碌状态并使用工具" {
    zhu.input.reset();
    defer zhu.input.reset();
    context.init();
    defer context.init();

    zhu.camera.init(.xy(640, 360));
    zhu.window.mouse = testTarget;
    setActiveItem(.hoe, 1);
    clickMouse(.LEFT);
    zhu.assets.allocator = std.testing.allocator;
    map.land.enter(&map.maps[0]);
    defer map.land.exit();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const player = addTestPlayer(&world, .xy(24, 40));

    update(&world);

    try std.testing.expect(world.has(player, Busy));
    try std.testing.expectEqual(Action.hoe, world.get(player, Actor).?.action);
    const velocity = world.get(player, Velocity).?;
    try std.testing.expect(velocity.value.approxEqual(.zero));
    try std.testing.expectEqual(
        Ground.dry,
        map.land.getTile(testTarget).?.ground.?,
    );
}

test "工具使用会浇水并标记作物" {
    zhu.assets.allocator = std.testing.allocator;
    map.land.enter(&map.maps[0]);
    defer map.land.exit();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    try std.testing.expect(map.land.hoe(testTarget));
    const crop = world.createEntity();
    world.add(crop, Crop{});
    map.land.getTile(testTarget).?.object = .{ .entity = crop };

    applyTool(&world, testTarget, .water);

    const tile = map.land.getTile(testTarget).?;
    try std.testing.expectEqual(Ground.wet, tile.ground.?);
    try std.testing.expect(world.get(crop, Crop).?.watered);
    const sounds = world.getEvent(event.SoundPlay);
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.water, sounds[0].id);
}

test "工具使用会种植种子并减少数量" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockImages();
    map.land.enter(&map.maps[0]);
    defer map.land.exit();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    setActiveItem(.strawberrySeed, 2);
    try std.testing.expect(map.land.hoe(testTarget));

    applyTool(&world, testTarget, .strawberrySeed);

    const sounds = world.getEvent(event.SoundPlay);
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.plant, sounds[0].id);
    try std.testing.expectEqual(1, inventory.activeItem().?.count);

    const cropEntity = map.land.getTile(testTarget).?.crop().?;
    try std.testing.expectEqual(
        CropEnum.strawberry,
        world.get(cropEntity, Crop).?.kind,
    );
}

test "工具使用会收获成熟作物" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockImages();
    map.land.enter(&map.maps[0]);
    defer map.land.exit();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const crop = world.createEntity();
    world.add(crop, Crop{ .stage = .mature, .kind = .potato });
    map.land.getTile(testTarget).?.object = .{ .entity = crop };

    zhu.random.init(1);
    applyTool(&world, testTarget, .hoe);

    const sounds = world.getEvent(event.SoundPlay);
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.harvest, sounds[0].id);
    try std.testing.expectEqual(null, map.land.getTile(testTarget).?.crop());

    var pickups = world.query(.{Pickup});
    const pickup = pickups.next().?;
    try std.testing.expectEqual(
        ItemEnum.potato,
        pickups.get(pickup, Pickup).item,
    );
}
