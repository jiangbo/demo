const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const map = @import("../map.zig");
const physics = map.physics;

const Position = component.Position;
const Velocity = component.motion.Velocity;
const Collider = component.motion.Collider;

pub fn update(world: *zhu.ecs.World, delta: f32) void {
    var query = world.query(.{ Position, Velocity });
    while (query.next()) |entity| {
        const velocity = query.get(entity, Velocity);
        const position = query.getPtr(entity, Position);
        const offset = velocity.value.scale(delta);

        const collider = world.get(entity, Collider);
        if (collider) |c| {
            // 轴分离碰撞解析：先尝试 X 轴移动，再尝试 Y 轴移动
            // 碰撞时回退到原始坐标，这样可以沿墙滑动而不会卡死
            var next = position.*;
            next.x += offset.x;
            if (physics.isBlocked(next, c, .xy(offset.x, 0))) next.x = position.x;
            next.y += offset.y;
            if (physics.isBlocked(next, c, .xy(0, offset.y))) next.y = position.y;
            position.* = next;
        } else {
            position.* = position.add(offset);
        }
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
