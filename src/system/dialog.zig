const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const factory = @import("../factory.zig");
const playerData = @import("../player.zig");

const dialog = component.dialog;
const Dialog = dialog.Dialog;
const Facing = component.Facing;
const Interact = component.Interact;
const Player = component.Player;
const Talk = dialog.Talk;
const WantMove = component.WantMove;

pub fn update(world: *ecs.World) void {
    const target = world.getIdentity(Interact) orelse return;
    const talk = world.get(target, Talk) orelse return;
    const index: usize = if (playerData.progress > 4) 1 else 0;

    const player = world.getIdentity(Player).?;
    const facing = world.get(player, Facing).?;
    world.add(target, component.oppositeFacing(facing));
    world.remove(target, WantMove);

    world.add(world.entity, Dialog{
        .lines = factory.dialogues[talk.dialogues[index]].lines,
    });
    world.add(player, Interact.Disabled{});
}

fn addTestPlayer(world: *ecs.World) ecs.Entity {
    world.entity = world.createEntity();
    const playerEntity = world.createIdentity(Player);
    world.add(playerEntity, Facing.down);
    return playerEntity;
}

test "交互对话人物后添加对话状态" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    _ = addTestPlayer(&world);
    const target = world.createEntity();
    world.addAll(target, .{
        Facing.down,
        Interact{},
        Talk{ .dialogues = factory.get(.xiaoChunChun).dialogues },
        WantMove{ .value = .xy(0, 1) },
    });
    world.addIdentity(target, Interact);

    const oldProgress = playerData.progress;
    defer playerData.progress = oldProgress;
    playerData.progress = 0;

    update(&world);
    try std.testing.expect(world.has(world.entity, Dialog));
    try std.testing.expect(world.hasIdentity(Player, Interact.Disabled));
    try std.testing.expectEqual(
        factory.dialogues[3].lines.len,
        world.get(world.entity, Dialog).?.lines.len,
    );
    try std.testing.expect(!world.has(target, Dialog));
    try std.testing.expectEqual(Facing.up, world.get(target, Facing).?);
    try std.testing.expect(!world.has(target, WantMove));
}

test "没有对话能力的交互对象不会开始对话" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    _ = addTestPlayer(&world);
    const target = world.createEntity();
    world.add(target, Interact{});
    world.addIdentity(target, Interact);

    update(&world);
    try std.testing.expect(!world.has(world.entity, Dialog));
}
