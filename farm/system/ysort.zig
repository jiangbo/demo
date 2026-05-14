const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");

pub fn update(registry: *zhu.ecs.Registry) void {
    var query = registry.query(.{ com.Render, com.YSort });
    while (query.next()) |entity| {
        const position = registry.get(entity, com.Position);
        const render = registry.getPtr(entity, com.Render);
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

    try std.testing.expectEqual(@as(f32, 42), registry.get(entity, com.Render).depth);
}
