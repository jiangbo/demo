const std = @import("std");
const zhu = @import("zhu");

const context = @import("context.zig");
const event = @import("event.zig");
const spawn = @import("spawn.zig");
const crop = @import("system/crop.zig");
const render = @import("system/render.zig");
const time = @import("system/time.zig");
const ysort = @import("system/ysort.zig");

const QueryPosition = struct { x: i32 = 0 };
const QueryVelocity = struct { x: i32 = 0 };
const QueryHidden = struct {};

test {
    std.testing.refAllDeclsRecursive(context);
    std.testing.refAllDeclsRecursive(event);
    std.testing.refAllDeclsRecursive(spawn);
    std.testing.refAllDeclsRecursive(crop);
    std.testing.refAllDeclsRecursive(render);
    std.testing.refAllDeclsRecursive(ysort);
}

test "ECS query can read and write cached component values" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, QueryPosition{ .x = 1 });
    world.add(entity, QueryVelocity{ .x = 2 });

    var query = world.query(.{ QueryPosition, QueryVelocity });
    const positions = query.query(QueryPosition);
    const velocities = query.query(QueryVelocity);
    const found = query.next().?;

    try std.testing.expectEqual(entity, found);
    try std.testing.expectEqual(@as(i32, 1), positions.get(found).x);

    const velocity = velocities.getPtr(found);
    velocity.x = 5;

    const worldVelocities = world.query(QueryVelocity);
    try std.testing.expectEqual(@as(i32, 5), worldVelocities.get(entity).x);
    try std.testing.expectEqual(null, query.next());
}

test "ECS viewNone keeps excluded components filtered" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const hidden = world.createEntity();
    world.add(hidden, QueryPosition{ .x = 1 });
    world.add(hidden, QueryHidden{});

    const visible = world.createEntity();
    world.add(visible, QueryPosition{ .x = 2 });

    var query = world.queryNone(.{QueryPosition}, .{QueryHidden});
    const positions = query.query(QueryPosition);
    const found = query.next().?;

    try std.testing.expectEqual(visible, found);
    try std.testing.expectEqual(@as(i32, 2), positions.get(found).x);
    try std.testing.expectEqual(null, query.next());
}
