const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const Position = component.Position;
const Render = component.render.Render;
const YSort = component.render.YSort;

pub fn update(world: *zhu.ecs.World) void {
    var query = world.query(.{ Render, Position, YSort });
    while (query.next()) |entity| {
        const position = query.get(entity, Position);
        query.getPtr(entity, Render).depth = position.y;
    }
}

test "YSort 会把位置 y 写入渲染深度" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Position.xy(10, 42));
    world.add(entity, Render{});
    world.add(entity, YSort{});

    update(&world);

    const renders = world.get(entity, Render).?;
    try std.testing.expectEqual(42, renders.depth);
}
