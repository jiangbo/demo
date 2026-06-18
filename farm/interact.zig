const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const context = @import("context.zig");
const factory = @import("factory.zig");
const inventory = @import("inventory.zig");
const map = @import("map.zig");
const spatial = map.spatial;
const ui = @import("ui.zig");

const World = zhu.ecs.World;
const Entity = zhu.ecs.Entity;
const Position = component.Position;
const Player = component.actor.Player;
const Npc = component.actor.Npc;
const Actor = component.actor.Actor;
const Dialog = component.actor.Dialog;
const Shape = component.motion.Shape;
const ItemEnum = component.item.ItemEnum;
const Chest = component.item.Chest;
const Animation = component.actor.Animation;
const Sprite = component.render.Sprite;
const Rest = component.map.Rest;

pub fn update(world: *World) void {
    // 当前对话目标走远或消失时，直接关闭对话。
    if (world.getIdentity(Dialog)) |target| checkDistance(world, target);

    // 交互按键由 input.zon 统一配置。
    if (!context.input.pressed(.interact)) return;

    if (world.getIdentity(Dialog)) |target| {
        advanceDialog(world, target);
    } else {
        tryInteract(world);
    }
}

// 检查玩家与当前对话 NPC 的距离，超限则关闭对话
fn checkDistance(world: *World, target: Entity) void {
    const player = world.getIdentity(Player).?;
    const playerPos = world.get(player, Position).?;
    const targetPos = world.get(target, Position) orelse {
        closeDialog(world, target);
        return;
    };

    const dist = playerPos.sub(targetPos).length();
    if (dist > Dialog.closeDist) closeDialog(world, target);
}

// 根据朝向构建探测矩形，用 markFacingHits 查找可交互目标。
fn tryInteract(world: *World) void {
    const player = world.getIdentity(Player).?;
    const playerPos = targetCenter(world, player);

    map.markFacingHits(world);
    defer world.clear(spatial.Hit);

    const target = nearestTarget(world, playerPos) orelse return;

    if (world.has(target, Dialog)) {
        return startDialog(world, target);
    }

    if (world.has(target, Chest)) return openChest(world, target);

    if (world.has(target, Rest)) return ui.rest.enter();
}

fn nearestTarget(world: *World, playerPos: Position) ?Entity {
    var bestEntity: ?Entity = null;
    var bestDist2: f32 = std.math.inf(f32);

    var query = world.query(.{ spatial.Hit, Position });
    while (query.next()) |entity| {
        const canTalk = world.has(entity, Npc) and world.has(entity, Dialog);
        const canOpen = world.has(entity, Chest);
        const canRest = world.has(entity, Rest);
        if (!canTalk and !canOpen and !canRest) continue;

        const pos = targetCenter(world, entity);
        const dist2 = playerPos.sub(pos).length2();
        if (dist2 < bestDist2) {
            bestDist2 = dist2;
            bestEntity = entity;
        }
    }

    return bestEntity;
}

fn targetCenter(world: *World, entity: Entity) Position {
    const position = world.get(entity, Position).?;
    const shape = world.get(entity, Shape).?;
    return shape.move(position).toRect().center();
}

fn openChest(world: *World, target: Entity) void {
    const chest = world.getPtr(target, Chest).?;
    showChestNotice(chest);

    // 宝箱奖励直接进入当前库存模块。
    for (std.enums.values(ItemEnum)) |itemType| {
        const count = chest.items.get(itemType);
        if (count == 0) continue;

        inventory.add(itemType, count);
    }
    chest.opened = true;

    const animation = world.getPtr(target, Animation).?;
    // anim_id 地图摆件已经是非循环动画，交互只负责重新播放。
    animation.reset();
    world.remove(target, Shape);
}

fn showChestNotice(chest: *const Chest) void {
    var buffer: [160]u8, var len: usize = .{ undefined, 0 };
    for (std.enums.values(ItemEnum)) |itemType| {
        const count = chest.items.get(itemType);
        if (count == 0) continue;

        const line = zhu.format(buffer[len..], "{s}{s} x{d}", .{
            if (len == 0) "" else "\n",
            factory.itemConfig(itemType).name,
            count,
        });
        len += line.len;
    }
    if (len == 0) return;

    context.notice.show("{s}", .{buffer[0..len]});
}

// 开始对话时把行号重置到第一句，并记录当前对话实体。
fn startDialog(world: *World, target: Entity) void {
    const dialog = world.getPtr(target, Dialog).?;
    if (dialog.lines.len == 0) return;

    dialog.index = 0;
    world.addIdentity(target, Dialog);
}

// 推进到下一句，超过最后一句就关闭。
fn advanceDialog(world: *World, target: Entity) void {
    const dialog = world.getPtr(target, Dialog) orelse {
        closeDialog(world, target);
        return;
    };

    dialog.index += 1;
    if (dialog.index >= dialog.lines.len) closeDialog(world, target);
}

// 关闭当前对话，并重置 NPC 自己的对话行号。
fn closeDialog(world: *World, target: Entity) void {
    const active = world.getIdentity(Dialog) orelse return;
    if (active != target) return;

    if (world.getPtr(target, Dialog)) |dialog| dialog.index = 0;
    world.removeIdentity(Dialog);
}

fn pressKey(keyCode: zhu.key.Code) void {
    var ev = zhu.window.Event{
        .type = .KEY_DOWN,
        .key_code = keyCode,
    };
    zhu.input.handle(&ev);
}

test "按 F 会激活最近 NPC 的第一句对话" {
    zhu.input.reset();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    // 玩家朝下
    const player = world.createIdentity(Player);
    world.add(player, Position.xy(0, 0));
    world.add(player, Actor{});
    world.add(player, Shape{ .rect = .init(.zero, .xy(8, 8)) });

    // 远处 NPC，不在探测框内
    const far = world.createEntity();
    world.add(far, Position.xy(48, 0));
    world.add(far, Npc{});
    world.add(far, Dialog{ .lines = &.{"远处 NPC"} });
    world.add(far, Shape{ .rect = .init(.zero, .xy(8, 8)) });

    // 近处 NPC，在玩家正下方探测框内
    const near = world.createEntity();
    world.add(near, Position.xy(0, 20));
    world.add(near, Npc{});
    world.add(near, Dialog{ .lines = &.{"近处 NPC"} });
    world.add(near, Shape{ .rect = .init(.zero, .xy(8, 8)) });

    pressKey(.F);
    update(&world);

    try std.testing.expectEqual(near, world.getIdentity(Dialog).?);
    try std.testing.expectEqual(0, world.get(near, Dialog).?.index);
}

test "对话激活后按 F 会推进并在末尾关闭" {
    zhu.input.reset();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.add(player, Position.xy(0, 0));

    const npc = world.createEntity();
    world.add(npc, Position.xy(16, 0));
    world.add(npc, Dialog{ .lines = &.{ "你好", "明天见" } });
    world.addIdentity(npc, Dialog);

    pressKey(.F);
    update(&world);

    try std.testing.expectEqual(npc, world.getIdentity(Dialog).?);
    try std.testing.expectEqual(1, world.get(npc, Dialog).?.index);

    zhu.input.reset();
    pressKey(.F);
    update(&world);

    try std.testing.expectEqual(null, world.getIdentity(Dialog));
    try std.testing.expectEqual(0, world.get(npc, Dialog).?.index);
}

test "当前对话目标太远时会直接关闭" {
    zhu.input.reset();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.add(player, Position.xy(0, 0));

    const npc = world.createEntity();
    world.add(npc, Position.xy(Dialog.closeDist + 1, 0));
    world.add(npc, Dialog{ .lines = &.{"你好"}, .index = 1 });
    world.addIdentity(npc, Dialog);

    update(&world);

    try std.testing.expectEqual(null, world.getIdentity(Dialog));
    try std.testing.expectEqual(0, world.get(npc, Dialog).?.index);
}

test "按 F 打开宝箱会重置打开动画" {
    zhu.input.reset();
    defer {
        inventory.reset();
        zhu.input.reset();
    }
    inventory.reset();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.add(player, Position.xy(0, 0));
    world.add(player, Actor{});
    world.add(player, Shape{ .rect = .init(.zero, .xy(8, 8)) });

    const frames = [_]zhu.graphics.Frame{
        .{ .offset = .xy(0, 0), .duration = 0.1 },
        .{ .offset = .xy(16, 0), .duration = 0.1 },
    };
    const image = zhu.graphics.Image{ .size = .xy(32, 16) };
    var animation = zhu.Animation.init(image, .xy(16, 16), &frames);
    animation.loop = false;
    animation.stop();

    const chest = world.createEntity();
    world.add(chest, Position.xy(0, 20));
    world.add(chest, Shape{ .rect = .init(.zero, .xy(8, 8)) });
    world.add(chest, Chest{});
    world.add(chest, animation);
    world.add(chest, Sprite{
        .image = image.sub(.init(.xy(16, 0), .xy(16, 16))),
    });

    pressKey(.F);
    update(&world);

    try std.testing.expect(world.get(chest, Chest).?.opened);
    try std.testing.expect(world.get(chest, Animation).?.isRunning());
    try std.testing.expect(!world.get(chest, Animation).?.loop);
}
