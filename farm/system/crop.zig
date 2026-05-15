const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");

pub fn update(world: *zhu.ecs.World, delta: f32) void {
    var query = world.query(.{com.Crop});
    while (query.next()) |entity| {
        const crop = query.getPtr(entity, com.Crop);
        crop.growth = @min(1, crop.growth + delta * 0.1);
    }
}

test "作物更新会增长并限制到一" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, com.Crop{ .growth = 0.95 });

    update(&world, 10);

    try std.testing.expectEqual(@as(f32, 1), world.query(com.Crop).get(entity).growth);
}
