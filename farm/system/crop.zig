const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");

pub fn update(registry: *zhu.ecs.Registry, delta: f32) void {
    var query = registry.view(.{com.Crop});
    const crops = query.query(com.Crop);
    while (query.next()) |entity| {
        const crop = crops.getPtr(entity);
        crop.growth = @min(1, crop.growth + delta * 0.1);
    }
}

test "作物更新会增长并限制到一" {
    var registry = zhu.ecs.Registry.init(std.testing.allocator);
    defer registry.deinit();

    const entity = registry.createEntity();
    registry.add(entity, com.Crop{ .growth = 0.95 });

    update(&registry, 10);

    try std.testing.expectEqual(@as(f32, 1), registry.query(com.Crop).get(entity).growth);
}
