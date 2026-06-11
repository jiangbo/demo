const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const map = @import("../map.zig");
const spatial = map.spatial;

const Position = component.Position;
const Player = component.actor.Player;
const Npc = component.actor.Npc;
const Actor = component.actor.Actor;
const Dialog = component.actor.Dialog;
const DialogAdvance = component.actor.DialogAdvance;
const DialogClose = component.actor.DialogClose;
const DialogStart = component.actor.DialogStart;
const Shape = component.motion.Shape;

pub fn update(world: *zhu.ecs.World) void {
    // 通过 Identity 查找当前正在对话的实体
    const activeEntity = world.getIdentity(Dialog);

    // 检查激活对话的距离，走远则自动关闭
    if (activeEntity) |target| checkDistance(world, target);

    // 按 F 键触发交互
    if (!zhu.key.pressed(.F)) return;

    if (activeEntity) |target| {
        // 有激活对话，推进下一句
        world.addIdentity(target, DialogAdvance);
    } else {
        // 没有激活对话，找最近的可交互 NPC
        tryInteract(world);
    }
}

// 检查玩家与当前对话 NPC 的距离，超限则关闭对话
fn checkDistance(world: *zhu.ecs.World, target: zhu.ecs.Entity) void {
    const player = world.getIdentity(Player).?;
    const playerPos = world.get(player, Position).?;
    const targetPos = world.get(target, Position) orelse {
        world.addIdentity(target, DialogClose);
        return;
    };

    const dist = playerPos.sub(targetPos).length();
    if (dist > Dialog.closeDist) {
        world.addIdentity(target, DialogClose);
    }
}

// 根据朝向构建探测矩形，用 markFacingHits 查找可交互 NPC
fn tryInteract(world: *zhu.ecs.World) void {
    const player = world.getIdentity(Player).?;
    const playerPos = world.get(player, Position).?;

    map.markFacingHits(world);
    defer world.clear(spatial.Hit);

    // 遍历命中的可对话 NPC，取距离最近的
    var bestEntity: ?zhu.ecs.Entity = null;
    var bestDist2: f32 = std.math.inf(f32);

    var query = world.query(.{ spatial.Hit, Position, Npc, Dialog });
    while (query.next()) |entity| {
        const pos = query.get(entity, Position);
        const dist2 = playerPos.sub(pos).length2();
        if (dist2 < bestDist2) {
            bestDist2 = dist2;
            bestEntity = entity;
        }
    }

    const target = bestEntity orelse return;

    world.addIdentity(target, DialogStart);
}

fn pressKey(keyCode: zhu.key.Code) void {
    var ev = zhu.window.Event{
        .type = .KEY_DOWN,
        .key_code = keyCode,
    };
    zhu.input.handle(&ev);
}

test "按 F 会向最近的 NPC 发起对话事件" {
    zhu.input.reset();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    // 玩家朝下
    const player = world.createIdentity(Player);
    world.add(player, Position.xy(0, 0));
    world.add(player, Actor{});

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

    try std.testing.expectEqual(near, world.takeIdentity(DialogStart).?);
}

test "对话激活后按 F 会发送推进事件" {
    zhu.input.reset();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.add(player, Position.xy(0, 0));

    const npc = world.createEntity();
    world.add(npc, Position.xy(16, 0));
    world.add(npc, Dialog{ .lines = &.{"你好"} });
    world.addIdentity(npc, Dialog);

    pressKey(.F);
    update(&world);

    try std.testing.expectEqual(npc, world.takeIdentity(DialogAdvance).?);
}

test "当前对话目标太远时会发送关闭事件" {
    zhu.input.reset();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.add(player, Position.xy(0, 0));

    const npc = world.createEntity();
    world.add(npc, Position.xy(Dialog.closeDist + 1, 0));
    world.add(npc, Dialog{ .lines = &.{"你好"} });
    world.addIdentity(npc, Dialog);

    update(&world);

    try std.testing.expectEqual(npc, world.takeIdentity(DialogClose).?);
}
