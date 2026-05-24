const std = @import("std");
const zhu = @import("zhu");

const QueryPosition = struct { x: i32 = 0 };
const QueryVelocity = struct { x: i32 = 0 };
const QueryHidden = struct {};

test {
    std.testing.refAllDeclsRecursive(@import("context.zig"));
    std.testing.refAllDeclsRecursive(@import("event.zig"));
    std.testing.refAllDeclsRecursive(@import("map.zig"));
    std.testing.refAllDeclsRecursive(@import("factory.zig"));
    std.testing.refAllDeclsRecursive(@import("system/animation.zig"));
    std.testing.refAllDeclsRecursive(@import("system/control.zig"));
    std.testing.refAllDeclsRecursive(@import("system/crop.zig"));
    std.testing.refAllDeclsRecursive(@import("system/movement.zig"));
    std.testing.refAllDeclsRecursive(@import("system/render.zig"));
    std.testing.refAllDeclsRecursive(@import("system/tool.zig"));
    std.testing.refAllDeclsRecursive(@import("system/wander.zig"));
    std.testing.refAllDeclsRecursive(@import("prefab.zig"));
}

test "ECS 查询可以读写缓存的组件值" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, QueryPosition{ .x = 1 });
    world.add(entity, QueryVelocity{ .x = 2 });

    var query = world.query(.{ QueryPosition, QueryVelocity });
    const found = query.next().?;

    try std.testing.expectEqual(entity, found);
    const position = query.get(found, QueryPosition);
    try std.testing.expectEqual(1, position.x);

    const velocity = query.getPtr(found, QueryVelocity);
    velocity.x = 5;

    const worldVelocity = query.get(entity, QueryVelocity);
    try std.testing.expectEqual(5, worldVelocity.x);
    try std.testing.expectEqual(null, query.next());
}

test "ECS viewNone 会过滤排除组件" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const hidden = world.createEntity();
    world.add(hidden, QueryPosition{ .x = 1 });
    world.add(hidden, QueryHidden{});

    const visible = world.createEntity();
    world.add(visible, QueryPosition{ .x = 2 });

    var query = world.queryNone(.{QueryPosition}, .{QueryHidden});
    const found = query.next().?;

    try std.testing.expectEqual(visible, found);
    const position = query.get(found, QueryPosition);
    try std.testing.expectEqual(2, position.x);
    try std.testing.expectEqual(null, query.next());
}
