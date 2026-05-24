const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");

const Action = component.actor.Action;
const Actor = component.actor.Actor;
const Facing = component.actor.Facing;
const Position = component.Position;
const Velocity = component.motion.Velocity;
const Wander = component.actor.Wander;

const arriveDistance2: f32 = 4.0;

pub fn update(world: *zhu.ecs.World, delta: f32) void {
    var query = world.query(.{ Position, Velocity, Actor, Wander });
    while (query.next()) |entity| {
        const position = query.get(entity, Position);
        const velocity = query.getPtr(entity, Velocity);
        const actor = query.getPtr(entity, Actor);
        const wander = query.getPtr(entity, Wander);

        if (wander.radius <= 0 or wander.speed <= 0) {
            stop(actor, velocity, wander);
            continue;
        }

        if (!wander.moving) {
            wander.waitTimer -= delta;
            velocity.value = .zero;
            actor.action = .idle;
            if (wander.waitTimer > 0) continue;
            chooseTarget(wander, position);
        }

        const toTarget = wander.target.sub(position);
        const distance2 = toTarget.length2();
        if (distance2 <= arriveDistance2) {
            stop(actor, velocity, wander);
            wander.waitTimer = zhu.randomF32(wander.minWait, wander.maxWait);
            continue;
        }

        const direction = toTarget.normalize();
        velocity.value = direction.scale(wander.speed);
        actor.action = Action.walk;
        actor.facing = facingFromDirection(direction);

        if (distance2 >= wander.lastDistance2 - 1.0) {
            wander.stuckTimer += delta;
            if (wander.stuckTimer >= wander.stuckReset) {
                stop(actor, velocity, wander);
                wander.waitTimer = zhu.randomF32(wander.minWait, wander.maxWait);
                continue;
            }
        } else {
            wander.stuckTimer = 0;
        }
        wander.lastDistance2 = distance2;
    }
}

fn chooseTarget(wander: *Wander, position: zhu.Vector2) void {
    const angle = zhu.randomF32(0, std.math.pi * 2.0);
    const radius = zhu.randomF32(0, wander.radius);
    const direction = zhu.Vector2.xy(@cos(angle), @sin(angle));
    wander.target = wander.home.add(direction.scale(radius));
    wander.moving = true;
    wander.stuckTimer = 0;
    wander.lastDistance2 = wander.target.sub(position).length2();
}

fn stop(actor: *Actor, velocity: *Velocity, wander: *Wander) void {
    velocity.value = .zero;
    actor.action = .idle;
    wander.moving = false;
}

fn facingFromDirection(direction: zhu.Vector2) Facing {
    if (@abs(direction.x) > @abs(direction.y)) {
        return if (direction.x < 0) .left else .right;
    }
    return if (direction.y < 0) .up else .down;
}

test "wander 会选择目标并写入速度" {
    zhu.math.setRandomSeed(1);

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Position.xy(10, 20));
    world.add(entity, Velocity{});
    world.add(entity, Actor{});
    world.add(entity, Wander{
        .home = .xy(10, 20),
        .radius = 32,
        .speed = 10,
    });

    update(&world, 0.1);

    const velocity = world.get(entity, Velocity).?;
    const actor = world.get(entity, Actor).?;
    const wander = world.get(entity, Wander).?;

    try std.testing.expect(wander.moving);
    try std.testing.expect(velocity.value.length2() > 0);
    try std.testing.expectEqual(Action.walk, actor.action);
}

test "wander 到达目标后进入等待" {
    zhu.math.setRandomSeed(1);

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Position.xy(10, 20));
    world.add(entity, Velocity{ .value = .xy(3, 0) });
    world.add(entity, Actor{ .action = .walk });
    world.add(entity, Wander{
        .home = .xy(10, 20),
        .radius = 32,
        .speed = 10,
        .target = .xy(11, 20),
        .moving = true,
    });

    update(&world, 0.1);

    const velocity = world.get(entity, Velocity).?;
    const actor = world.get(entity, Actor).?;
    const wander = world.get(entity, Wander).?;

    try std.testing.expect(!wander.moving);
    try std.testing.expect(wander.waitTimer > 0);
    try std.testing.expect(velocity.value.approxEqual(.zero));
    try std.testing.expectEqual(Action.idle, actor.action);
}
