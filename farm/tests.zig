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
    var registry = zhu.ecs.Registry.init(std.testing.allocator);
    defer registry.deinit();

    const entity = registry.createEntity();
    registry.add(entity, QueryPosition{ .x = 1 });
    registry.add(entity, QueryVelocity{ .x = 2 });

    var query = registry.view(.{ QueryPosition, QueryVelocity });
    const positions = query.query(QueryPosition);
    const velocities = query.query(QueryVelocity);
    const found = query.next().?;

    try std.testing.expectEqual(entity, found);
    try std.testing.expectEqual(@as(i32, 1), positions.get(found).x);

    const velocity = velocities.getPtr(found);
    velocity.x = 5;

    const registryVelocities = registry.query(QueryVelocity);
    try std.testing.expectEqual(@as(i32, 5), registryVelocities.get(entity).x);
    try std.testing.expectEqual(null, query.next());
}

test "ECS viewNone keeps excluded components filtered" {
    var registry = zhu.ecs.Registry.init(std.testing.allocator);
    defer registry.deinit();

    const hidden = registry.createEntity();
    registry.add(hidden, QueryPosition{ .x = 1 });
    registry.add(hidden, QueryHidden{});

    const visible = registry.createEntity();
    registry.add(visible, QueryPosition{ .x = 2 });

    var query = registry.viewNone(.{QueryPosition}, .{QueryHidden});
    const positions = query.query(QueryPosition);
    const found = query.next().?;

    try std.testing.expectEqual(visible, found);
    try std.testing.expectEqual(@as(i32, 2), positions.get(found).x);
    try std.testing.expectEqual(null, query.next());
}
