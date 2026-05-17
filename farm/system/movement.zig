const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");

const Position = component.Position;
const Velocity = component.Velocity;

pub fn update(world: *zhu.ecs.World, delta: f32) void {
    var query = world.query(.{ Position, Velocity });
    while (query.next()) |entity| {
        const velocity = query.get(entity, Velocity);
        const position = query.getPtr(entity, Position);
        position.* = position.add(velocity.value.scale(delta));
    }
}

test "移动系统会按速度更新位置" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Position.xy(10, 20));
    world.add(entity, Velocity{ .value = .xy(3, -4) });

    update(&world, 0.5);

    const position = world.get(entity, Position).?;
    try std.testing.expect(position.approxEqual(.xy(11.5, 18)));
}
