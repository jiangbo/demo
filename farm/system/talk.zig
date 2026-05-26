const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");

const Position = component.Position;
const Player = component.actor.Player;
const Npc = component.actor.Npc;
const Dialog = component.actor.Dialog;
const event = component.event;

pub fn update(world: *zhu.ecs.World) void {
    // 通过 Identity 查找当前正在对话的实体
    const activeEntity = world.getIdentity(Dialog);

    // 检查激活对话的距离，走远则自动关闭
    if (activeEntity) |target| checkDistance(world, target);

    // 按 F 键触发交互
    if (!zhu.input.key.pressed(.F)) return;

    if (activeEntity) |target| {
        // 有激活对话，推进下一句
        world.addEvent(event.DialogAdvance{ .entity = target });
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
        world.addEvent(event.DialogClose{ .entity = target });
        return;
    };

    const dist = playerPos.sub(targetPos).length();
    if (dist > Dialog.closeDist) {
        world.addEvent(event.DialogClose{ .entity = target });
    }
}

// 遍历所有可对话 NPC，找距离最近的发起对话
fn tryInteract(world: *zhu.ecs.World) void {
    const player = world.getIdentity(Player).?;
    const playerPos = world.get(player, Position).?;

    var bestEntity: ?zhu.ecs.Entity = null;
    var bestDist2: f32 = Dialog.interactDist * Dialog.interactDist;

    var query = world.query(.{ Position, Npc, Dialog });
    while (query.next()) |entity| {
        const pos = query.get(entity, Position);

        const dist2 = playerPos.sub(pos).length2();
        if (dist2 <= bestDist2) {
            bestDist2 = dist2;
            bestEntity = entity;
        }
    }

    const target = bestEntity orelse return;

    world.addEvent(event.DialogStart{
        .entity = target,
        .scriptId = world.getPtr(target, Dialog).?.scriptId,
    });
}

fn resetInput() void {
    zhu.input.key.state = .initEmpty();
    zhu.input.key.lastState = .initEmpty();
}

fn pressKey(keyCode: zhu.input.KeyCode) void {
    zhu.input.key.state.set(@intCast(@intFromEnum(keyCode)));
}

test "按 F 会向最近的 NPC 发起对话事件" {
    resetInput();
    defer resetInput();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.add(player, Position.xy(0, 0));

    const far = world.createEntity();
    world.add(far, Position.xy(48, 0));
    world.add(far, Npc{});
    world.add(far, Dialog{ .scriptId = "sheep" });

    const near = world.createEntity();
    world.add(near, Position.xy(24, 0));
    world.add(near, Npc{});
    world.add(near, Dialog{ .scriptId = "cow" });

    pressKey(.F);
    update(&world);

    const events = world.getEvents(component.event.DialogStart).items;
    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqual(near, events[0].entity);
    try std.testing.expectEqualStrings("cow", events[0].scriptId);
}

test "对话激活后按 F 会发送推进事件" {
    resetInput();
    defer resetInput();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.add(player, Position.xy(0, 0));

    const npc = world.createEntity();
    world.add(npc, Position.xy(16, 0));
    world.add(npc, Dialog{ .scriptId = "cow" });
    world.addIdentity(npc, Dialog);

    pressKey(.F);
    update(&world);

    const events = world.getEvents(component.event.DialogAdvance).items;
    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqual(npc, events[0].entity);
}

test "当前对话目标太远时会发送关闭事件" {
    resetInput();
    defer resetInput();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.add(player, Position.xy(0, 0));

    const npc = world.createEntity();
    world.add(npc, Position.xy(Dialog.closeDist + 1, 0));
    world.add(npc, Dialog{ .scriptId = "cow" });
    world.addIdentity(npc, Dialog);

    update(&world);

    const events = world.getEvents(component.event.DialogClose).items;
    try std.testing.expectEqual(@as(usize, 1), events.len);
    try std.testing.expectEqual(npc, events[0].entity);
}
