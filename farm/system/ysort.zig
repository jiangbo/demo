const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");

pub fn update(registry: *zhu.ecs.Registry) void {
    var query = registry.view(.{ com.Render, com.Position, com.YSort });
    const positions = query.query(com.Position);
    const renders = query.query(com.Render);
    while (query.next()) |entity| {
        const position = positions.get(entity);
        const render = renders.getPtr(entity);
        render.depth = position.y;
    }
}

test "YSort 会把位置的 y 写入渲染深度" {
    var registry = zhu.ecs.Registry.init(std.testing.allocator);
    defer registry.deinit();

    const entity = registry.createEntity();
    registry.add(entity, com.Position.xy(10, 42));
    registry.add(entity, com.Render{});
    registry.add(entity, com.YSort{});

    update(&registry);

    try std.testing.expectEqual(
        @as(f32, 42),
        registry.query(com.Render).get(entity).depth,
    );
}
