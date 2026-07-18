const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const input = @import("../input.zig");

const Actor = component.Actor;
const Player = component.Player;
const WantMove = component.WantMove;

pub fn update(world: *ecs.World) void {
    const entity = world.getIdentity(Player).?;
    const actor = world.getPtr(entity, Actor).?;
    const wantMove = world.getPtr(entity, WantMove).?;

    const direction = readDirection();
    if (direction.length2() == 0) {
        wantMove.direction = .zero;
        return;
    }

    if (chooseFacing(direction)) |facing| actor.facing = facing;
    wantMove.direction = direction.normalize();
}

fn readDirection() zhu.Vector2 {
    var direction: zhu.Vector2 = .zero;

    if (input.held(.up)) direction.y -= 1;
    if (input.held(.down)) direction.y += 1;
    if (input.held(.left)) direction.x -= 1;
    if (input.held(.right)) direction.x += 1;
    return direction;
}

fn chooseFacing(direction: zhu.Vector2) ?component.Facing {
    if (@abs(direction.x) > @abs(direction.y)) {
        return if (direction.x < 0) .left else .right;
    } else if (@abs(direction.y) > @abs(direction.x)) {
        return if (direction.y < 0) .up else .down;
    }

    // 两个轴相等时，新按下的方向决定角色朝向。
    if (input.pressed(.right)) return .right;
    if (input.pressed(.left)) return .left;
    if (input.pressed(.down)) return .down;
    if (input.pressed(.up)) return .up;
    return null;
}

test "斜向移动使用最后按下的方向" {
    zhu.input.reset();
    defer zhu.input.reset();

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createIdentity(Player);
    world.add(entity, Player{});
    world.add(entity, Actor{ .position = .zero, .facing = .down });
    world.add(entity, WantMove{});

    zhu.key.set(.W, true);
    update(&world);
    var actor = world.get(entity, Actor).?;
    var wantMove = world.get(entity, WantMove).?;
    try std.testing.expect(wantMove.direction.approxEqual(.xy(0, -1)));
    try std.testing.expectEqual(component.Facing.up, actor.facing);

    zhu.input.update();
    zhu.key.set(.D, true);
    update(&world);
    actor = world.get(entity, Actor).?;
    wantMove = world.get(entity, WantMove).?;
    try std.testing.expectApproxEqAbs(1, wantMove.direction.length(), 0.001);
    try std.testing.expectEqual(component.Facing.right, actor.facing);

    zhu.input.update();
    zhu.key.set(.D, false);
    update(&world);
    actor = world.get(entity, Actor).?;
    wantMove = world.get(entity, WantMove).?;
    try std.testing.expect(wantMove.direction.approxEqual(.xy(0, -1)));
    try std.testing.expectEqual(component.Facing.up, actor.facing);
}
