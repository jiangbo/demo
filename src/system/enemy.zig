const std = @import("std");
const ecs = @import("ecs");

const component = @import("../component.zig");

const Collider = component.Collider;
const Enemy = component.Enemy;
const Facing = component.Facing;
const Player = component.Player;
const Position = component.Position;

pub fn update(world: *ecs.World, delta: f32) void {
    const player = world.getIdentity(Player).?;
    const position = world.get(player, Position).?;
    const collider = world.get(player, Collider).?;
    const area = collider.move(position);

    var query = world.query(.{ Position, Enemy });
    while (query.next()) |entity| {
        const pos = query.get(entity, Position);
        const enemy = query.getPtr(entity, Enemy);
        if (enemy.wait > 0) {
            enemy.wait -= delta;
            continue;
        }
        if (!area.intersect(enemy.value.move(pos))) continue;

        const facing = world.get(player, Facing).?;
        world.add(entity, component.oppositeFacing(facing));
        world.addIdentity(entity, Enemy);
        return;
    }
}

test "玩家进入敌人区域后选择战斗对象" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.addAll(player, .{
        Position.zero,
        Collider.init(.xy(-8, -16), .xy(16, 16)),
        Facing.down,
    });

    const entity = world.createEntity();
    world.addAll(entity, .{
        Position.xy(0, 32),
        Enemy{ .value = .init(.xy(-24, -40), .xy(48, 48)) },
        Facing.down,
    });

    update(&world, 1);

    try std.testing.expectEqual(entity, world.getIdentity(Enemy).?);
    try std.testing.expectEqual(Facing.up, world.get(entity, Facing).?);
}

test "玩家在敌人区域外时不选择战斗对象" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.addAll(player, .{
        Position.zero,
        Collider.init(.xy(-8, -16), .xy(16, 16)),
        Facing.down,
    });

    const entity = world.createEntity();
    world.addAll(entity, .{
        Position.xy(100, 100),
        Enemy{ .value = .init(.xy(-24, -40), .xy(48, 48)) },
        Facing.down,
    });

    update(&world, 1);

    try std.testing.expectEqual(null, world.getIdentity(Enemy));
}

test "逃跑冷却期间不再触发战斗" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.addAll(player, .{
        Position.zero,
        Collider.init(.xy(-8, -16), .xy(16, 16)),
        Facing.down,
    });

    const entity = world.createEntity();
    world.addAll(entity, .{
        Position.xy(0, 32),
        Enemy{
            .value = .init(.xy(-24, -40), .xy(48, 48)),
            .wait = 0.5,
        },
        Facing.down,
    });

    update(&world, 0.25);

    try std.testing.expectEqual(null, world.getIdentity(Enemy));
    try std.testing.expectEqual(
        @as(f32, 0.25),
        world.get(entity, Enemy).?.wait,
    );
}
