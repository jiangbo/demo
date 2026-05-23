const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const context = @import("../context.zig");

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
    if (context.ui.wantCaptureKeyboard) return .zero;

    var direction: zhu.Vector2 = .zero;
    if (zhu.input.key.anyDown(&.{ .A, .LEFT })) direction.x -= 1;
    if (zhu.input.key.anyDown(&.{ .D, .RIGHT })) direction.x += 1;
    if (zhu.input.key.anyDown(&.{ .W, .UP })) direction.y -= 1;
    if (zhu.input.key.anyDown(&.{ .S, .DOWN })) direction.y += 1;

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
    zhu.input.key.state = .initEmpty();
    zhu.input.key.lastState = .initEmpty();
    context.ui.wantCaptureKeyboard = false;
}

fn setKey(keyCode: zhu.input.KeyCode) void {
    zhu.input.key.state.set(@intCast(@intFromEnum(keyCode)));
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

test "界面捕获键盘时玩家不会移动" {
    resetInput();
    defer resetInput();

    context.ui.wantCaptureKeyboard = true;
    setKey(.D);

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.add(player, Velocity{});
    world.add(player, Actor{});

    update(&world);

    const velocity = world.get(player, Velocity).?;
    try std.testing.expect(velocity.value.approxEqual(.zero));
}
