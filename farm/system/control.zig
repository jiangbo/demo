const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");

const Actor = component.actor.Actor;
const Facing = component.actor.Facing;
const Player = component.actor.Player;
const Action = component.actor.Action;
const Velocity = component.motion.Velocity;

const playerSpeed: f32 = 60;

pub fn update(world: *zhu.ecs.World) void {
    const direction = readDirection();
    const velocity = direction.scale(playerSpeed);
    const player = world.getIdentity(Player).?;
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
    if (zhu.key.anyHeld(&.{ .A, .LEFT })) direction.x -= 1;
    if (zhu.key.anyHeld(&.{ .D, .RIGHT })) direction.x += 1;
    if (zhu.key.anyHeld(&.{ .W, .UP })) direction.y -= 1;
    if (zhu.key.anyHeld(&.{ .S, .DOWN })) direction.y += 1;

    if (direction.length2() > 1) return direction.normalize();
    return direction;
}

fn facingFromDirection(direction: zhu.Vector2) Facing {
    if (@abs(direction.x) > @abs(direction.y)) {
        return if (direction.x < 0) .left else .right;
    }
    return if (direction.y < 0) .up else .down;
}

fn resetInput() void {
    zhu.input.reset();
}

fn setKey(keyCode: zhu.key.Code) void {
    var ev = zhu.window.Event{
        .type = .KEY_DOWN,
        .key_code = keyCode,
    };
    zhu.input.handle(&ev);
}

test "玩家控制会把方向键写入速度" {
    resetInput();
    defer resetInput();

    setKey(.D);
    setKey(.W);

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.add(player, Velocity{});
    world.add(player, Actor{});

    update(&world);

    const velocity = world.get(player, Velocity).?;
    try std.testing.expect(velocity.value.x > 0);
    try std.testing.expect(velocity.value.y < 0);
    try std.testing.expectApproxEqAbs(playerSpeed, velocity.value.length(), 0.01);

    const actor = world.get(player, Actor).?;
    try std.testing.expectEqual(Action.walk, actor.action);
    try std.testing.expectEqual(Facing.up, actor.facing);
}
