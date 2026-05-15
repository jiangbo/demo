const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");

pub fn update(world: *zhu.ecs.World) void {
    var query = world.query(.{ com.Render, com.Position, com.YSort });
    while (query.next()) |entity| {
        const position = query.get(entity, com.Position);
        const render = query.getPtr(entity, com.Render);
        render.depth = position.y;
    }
}

test "YSort 会把位置的 y 写入渲染深度" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, com.Position.xy(10, 42));
    world.add(entity, com.Render{});
    world.add(entity, com.YSort{});

    update(&world);

    try std.testing.expectEqual(
        @as(f32, 42),
        world.query(com.Render).get(entity).depth,
    );
}
