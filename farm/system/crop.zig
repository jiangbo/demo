const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const Crop = component.Crop;

pub fn update(world: *zhu.ecs.World, delta: f32) void {
    var view = world.view(.{Crop});
    while (view.next()) |entity| {
        const crop = view.query(Crop).getPtr(entity);
        crop.growth = @min(1, crop.growth + delta * 0.1);
    }
}

test "作物更新会增长并限制到一" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Crop{ .growth = 0.95 });

    update(&world, 10);

    const crop = world.query(Crop).get(entity);
    try std.testing.expectEqual(1, crop.growth);
}
