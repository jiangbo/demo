const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const inventory = @import("../inventory.zig");
const map = @import("../map.zig");
const state = @import("../state.zig");

const Actor = component.actor.Actor;
const Facing = component.actor.Facing;
const Player = component.actor.Player;
const Action = component.actor.Action;
const Busy = component.actor.Busy;
const WantUse = component.actor.WantUse;
const Position = component.Position;
const Target = component.ui.Target;
const Velocity = component.motion.Velocity;
const ItemEnum = component.item.ItemEnum;
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
    if (state.input.held(.moveLeft)) direction.x -= 1;
    if (state.input.held(.moveRight)) direction.x += 1;
    if (state.input.held(.moveUp)) direction.y -= 1;
    if (state.input.held(.moveDown)) direction.y += 1;

    if (direction.length2() > 1) return direction.normalize();
    return direction;
}

fn targetPosition(world: *World, player: Entity) ?zhu.Vector2 {
    if (state.input.mouseCaptured) return null;

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
    if (!isTargetItem(item)) return;

    const position = targetPosition(world, player) orelse return;

    target.position = position;
    target.active = true;

    if (!state.input.mousePressed(.LEFT)) return;
    const actor = world.getPtr(player, Actor).?;
    const playerPos = world.get(player, Position).?;
    // 朝向按点击位置计算，目标格只负责工具结算。
    const mouseWorld = zhu.camera.toWorld(zhu.window.mouse);
    const direction = mouseWorld.sub(playerPos);
    if (!direction.approxEqual(.zero)) {
        actor.facing = facingFromDirection(direction);
    }

    actor.action = actionFromItem(item);
    world.getPtr(player, Velocity).?.value = .zero;
    world.add(player, WantUse{ .item = item, .target = position });
    world.add(player, Busy{});
}

fn isTargetItem(item: ItemEnum) bool {
    return switch (item) {
        .hoe, .water, .pickaxe, .axe, .sickle => true,
        .strawberrySeed, .potatoSeed => true,
        .strawberry, .potato, .timber, .stone => false,
    };
}

fn actionFromItem(item: ItemEnum) Action {
    return switch (item) {
        .hoe => .hoe,
        .water => .watering,
        .pickaxe => .pickaxe,
        .axe => .axe,
        .sickle => .sickle,
        .strawberrySeed, .potatoSeed => .planting,
        .strawberry, .potato, .timber, .stone => unreachable,
    };
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

test "玩家控制会把方向键写入速度" {
    zhu.input.reset();
    defer zhu.input.reset();

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

test "点击目标只写入使用意图" {
    zhu.input.reset();
    defer zhu.input.reset();

    zhu.camera.init(.xy(640, 360));
    zhu.window.mouse = testTarget;
    setActiveItem(.hoe, 1);
    clickMouse(.LEFT);
    zhu.assets.allocator = std.testing.allocator;
    map.spatial.enter(&map.maps[0]);
    defer map.spatial.exit();
    map.land.enter(&map.maps[0]);
    defer map.land.exit();
    map.spatial.tiles[map.maps[0].worldToTileIndex(testTarget).?]
        .insert(.arable);

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const player = addTestPlayer(&world, .xy(24, 40));

    update(&world);

    try std.testing.expect(world.has(player, Busy));
    try std.testing.expectEqual(Action.hoe, world.get(player, Actor).?.action);
    const want = world.get(player, WantUse).?;
    try std.testing.expectEqual(ItemEnum.hoe, want.item);
    try std.testing.expect(want.target.approxEqual(testTarget));
    const velocity = world.get(player, Velocity).?;
    try std.testing.expect(velocity.value.approxEqual(.zero));
    try std.testing.expectEqual(null, map.land.getTile(testTarget).?.ground);
}
