const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const context = @import("../context.zig");

const Player = component.Player;
const Velocity = component.Velocity;

const playerSpeed: f32 = 60;

pub fn update(world: *zhu.ecs.World) void {
    const direction = readDirection();
    const velocity = direction.scale(playerSpeed);
    const player = world.getIdentityEntity(Player) orelse return;
    if (world.getPtr(player, Velocity)) |v| v.value = velocity;
}

fn readDirection() zhu.Vector2 {
    if (context.uiWantCaptureKeyboard) return .zero;

    var direction: zhu.Vector2 = .zero;

    if (zhu.input.key.anyDown(&.{ .A, .LEFT })) direction.x -= 1;
    if (zhu.input.key.anyDown(&.{ .D, .RIGHT })) direction.x += 1;
    if (zhu.input.key.anyDown(&.{ .W, .UP })) direction.y -= 1;
    if (zhu.input.key.anyDown(&.{ .S, .DOWN })) direction.y += 1;

    if (direction.length2() > 1) return direction.normalize();
    return direction;
}

fn resetInput() void {
    zhu.input.key.state = .initEmpty();
    zhu.input.key.lastState = .initEmpty();
    context.uiWantCaptureKeyboard = false;
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

    const player = world.createIdentityEntity(Player);
    world.add(player, Velocity{});

    update(&world);

    const velocity = world.get(player, Velocity).?;
    try std.testing.expect(velocity.value.x > 0);
    try std.testing.expect(velocity.value.y < 0);
    try std.testing.expectApproxEqAbs(playerSpeed, velocity.value.length(), 0.01);
}

test "界面捕获键盘时玩家不会移动" {
    resetInput();
    defer resetInput();

    context.uiWantCaptureKeyboard = true;
    setKey(.D);

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentityEntity(Player);
    world.add(player, Velocity{});

    update(&world);

    const velocity = world.get(player, Velocity).?;
    try std.testing.expect(velocity.value.approxEqual(.zero));
}
