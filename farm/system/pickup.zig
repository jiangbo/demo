const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const context = @import("../context.zig");
const factory = @import("../factory.zig");
const inventory = @import("../inventory.zig");

const Player = component.actor.Player;
const Position = component.Position;
const Shape = component.motion.Shape;
const Pickup = component.item.Pickup;
const PickupMotion = component.item.PickupMotion;
const event = component.event;
const World = zhu.ecs.World;

const arcHeight: f32 = 6;

pub fn update(world: *World, delta: f32) void {
    updateMotion(world, delta);

    const player = world.getIdentity(Player).?;
    const playerShape = worldShape(world, player) orelse return;

    var query = world.query(.{ Pickup, Position, Shape }).reverse();
    while (query.next()) |entity| {
        if (world.has(entity, PickupMotion)) continue;

        const pickup = query.getPtr(entity, Pickup);
        const pickupShape = worldShape(world, entity) orelse continue;
        if (!playerShape.intersect(pickupShape)) continue;

        const remaining = inventory.add(pickup.item, pickup.count);
        const taken = pickup.count - remaining;
        pickup.count = remaining;

        var buffer: [96]u8, var len: usize = .{ undefined, 0 };
        if (taken > 0) {
            const line = zhu.format(buffer[len..], "获得 {s} x{d}", .{
                factory.itemConfig(pickup.item).name,
                taken,
            });
            len += line.len;
        }
        if (remaining > 0) {
            const line = zhu.format(buffer[len..], "{s}背包已满", .{
                if (len == 0) "" else "\n",
            });
            len += line.len;
        }
        if (len > 0) context.notice.show(.item, "{s}", .{buffer[0..len]});
        if (remaining > 0) continue;

        world.destroyEntity(entity);
        world.addEvent(event.SoundPlay{ .id = .pickup });
    }
}

fn updateMotion(world: *World, delta: f32) void {
    var query = world.query(.{ PickupMotion, Position });
    while (query.next()) |entity| {
        const motion = query.getPtr(entity, PickupMotion);
        const pos = query.getPtr(entity, Position);

        const running = motion.timer.updateRunning(delta);
        const t = motion.timer.progress();
        const inv = 1 - t;
        const eased = 1 - inv * inv * inv;

        // 位置沿水平散射方向插值，Y 轴额外叠加抛物线弧度。
        pos.* = motion.start.mix(motion.target, eased);
        pos.y -= @sin(t * std.math.pi) * arcHeight;

        if (running) continue;
        pos.* = motion.target;
        world.remove(entity, PickupMotion);
    }
}

fn worldShape(world: *World, entity: zhu.ecs.Entity) ?Shape {
    const position = world.get(entity, Position) orelse return null;
    const shape = world.get(entity, Shape) orelse return null;
    return shape.move(position);
}

test "pickup 飞散期间不会被拾取" {
    inventory.reset();
    defer inventory.reset();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.add(player, Position.xy(0, 0));
    world.add(player, Shape{ .circle = .init(.zero, 6) });

    const pickup = world.createEntity();
    world.add(pickup, Position.xy(0, 0));
    world.add(pickup, Pickup{ .item = .potato });
    world.add(pickup, PickupMotion{
        .start = .zero,
        .target = .xy(8, 0),
        .timer = .init(0.1),
    });
    world.add(pickup, Shape{ .rect = .init(.xy(-5, -5), .xy(10, 10)) });

    update(&world, 0.05);

    try std.testing.expect(world.get(pickup, Pickup) != null);
    try std.testing.expectEqual(0, world.getEvent(event.SoundPlay).len);
}

test "pickup 碰撞后会被销毁并播放音效" {
    inventory.reset();
    defer inventory.reset();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.add(player, Position.xy(0, 0));
    world.add(player, Shape{ .circle = .init(.zero, 6) });

    const pickup = world.createEntity();
    world.add(pickup, Position.xy(0, 0));
    world.add(pickup, Pickup{ .item = .potato, .count = 2 });
    world.add(pickup, Shape{ .rect = .init(.xy(-5, -5), .xy(10, 10)) });

    update(&world, 0.016);

    try std.testing.expectEqual(null, world.get(pickup, Pickup));

    const sounds = world.getEvent(event.SoundPlay);
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.pickup, sounds[0].id);
}

test "背包满时 pickup 不会消失" {
    inventory.reset();
    defer inventory.reset();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.add(player, Position.xy(0, 0));
    world.add(player, Shape{ .circle = .init(.zero, 6) });

    for (inventory.store.stacks) |*stack| {
        stack.* = .{ .item = .hoe, .count = 1 };
    }

    const pickup = world.createEntity();
    world.add(pickup, Position.xy(0, 0));
    world.add(pickup, Pickup{ .item = .potato, .count = 2 });
    world.add(pickup, Shape{ .rect = .init(.xy(-5, -5), .xy(10, 10)) });

    update(&world, 0.016);

    try std.testing.expectEqual(@as(u32, 2), world.get(pickup, Pickup).?.count);
    try std.testing.expectEqual(0, world.getEvent(event.SoundPlay).len);
}

test "背包只有部分空间时 pickup 只减少已拾取数量" {
    inventory.reset();
    defer inventory.reset();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.add(player, Position.xy(0, 0));
    world.add(player, Shape{ .circle = .init(.zero, 6) });

    for (inventory.store.stacks) |*stack| {
        stack.* = .{ .item = .hoe, .count = 1 };
    }
    inventory.store.stacks[0] = .{ .item = .potato, .count = 98 };

    const pickup = world.createEntity();
    world.add(pickup, Position.xy(0, 0));
    world.add(pickup, Pickup{ .item = .potato, .count = 3 });
    world.add(pickup, Shape{ .rect = .init(.xy(-5, -5), .xy(10, 10)) });

    update(&world, 0.016);

    try std.testing.expectEqual(@as(u32, 99), inventory.store.stacks[0].count);
    try std.testing.expectEqual(@as(u32, 2), world.get(pickup, Pickup).?.count);
    try std.testing.expectEqual(0, world.getEvent(event.SoundPlay).len);
}
