const std = @import("std");
const zhu = @import("zhu");

const com = @import("component.zig");

pub fn init() void {
    std.log.info("spawn init", .{});
}

pub fn deinit() void {}

pub fn loadFarm(registry: *zhu.ecs.Registry) void {
    const player = registry.createEntity();
    registry.add(player, com.Player{});
    registry.add(player, com.Position.xy(160, 96));

    const crop = registry.createEntity();
    registry.add(crop, com.Crop{ .growth = 0 });
    registry.add(crop, com.Position.xy(176, 96));

    const farmland = registry.createEntity();
    registry.add(farmland, com.Farmland{});
    registry.add(farmland, com.Position.xy(176, 112));

    std.log.info("farm loaded entities player={} crop={} farmland={}", .{
        player.index,
        crop.index,
        farmland.index,
    });
}

test "loadFarm 创建初始农场实体" {
    var registry = zhu.ecs.Registry.init(std.testing.allocator);
    defer registry.deinit();

    loadFarm(&registry);

    try std.testing.expectEqual(@as(usize, 1), registry.assure(com.Player).dense.items.len);
    try std.testing.expectEqual(@as(usize, 1), registry.raw(com.Crop).len);
    try std.testing.expectEqual(@as(usize, 1), registry.raw(com.Farmland).len);
}
