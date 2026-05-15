const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const Position = component.Position;
const Render = component.Render;
const YSort = component.YSort;

pub fn update(world: *zhu.ecs.World) void {
    var view = world.view(.{ Render, Position, YSort });
    while (view.next()) |entity| {
        const position = view.query(Position).get(entity);
        const render = view.query(Render).getPtr(entity);
        render.depth = position.y;
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

    const renders = world.query(Render).get(entity);
    try std.testing.expectEqual(42, renders.depth);
}
