const std = @import("std");
const zhu = @import("zhu");

const com = @import("component.zig");

pub fn init() void {
    std.log.info("spawn init", .{});
}

pub fn deinit() void {}

pub fn loadFarm(registry: *zhu.ecs.Registry) void {
    const player = registry.toIndex(registry.createEntity()).?;
    registry.add(player, com.Player{});
    registry.add(player, com.Position.xy(160, 96));
    registry.add(player, com.Sprite{
        .image = zhu.batch.whiteImage,
        .offset = .xy(-6, -18),
        .size = .xy(12, 18),
    });
    registry.add(player, com.Render{
        .layer = .actor,
        .color = .rgb(0.92, 0.82, 0.64),
    });
    registry.add(player, com.YSort{});

    const crop = registry.toIndex(registry.createEntity()).?;
    registry.add(crop, com.Crop{ .growth = 0 });
    registry.add(crop, com.Position.xy(176, 96));
    registry.add(crop, com.Sprite{
        .image = zhu.batch.whiteImage,
        .offset = .xy(-6, -10),
        .size = .xy(12, 10),
    });
    registry.add(crop, com.Render{
        .layer = .crop,
        .color = .rgb(0.24, 0.68, 0.28),
    });
    registry.add(crop, com.YSort{});

    const farmland = registry.toIndex(registry.createEntity()).?;
    registry.add(farmland, com.Farmland{});
    registry.add(farmland, com.Position.xy(176, 112));
    registry.add(farmland, com.Sprite{
        .image = zhu.batch.whiteImage,
        .offset = .xy(-8, -8),
        .size = .xy(16, 16),
    });
    registry.add(farmland, com.Render{
        .layer = .ground,
        .color = .rgb(0.47, 0.28, 0.16),
    });

    std.log.info("farm loaded entities player={} crop={} farmland={}", .{
        player,
        crop,
        farmland,
    });
}

test "loadFarm 创建初始农场实体" {
    var registry = zhu.ecs.Registry.init(std.testing.allocator);
    defer registry.deinit();

    loadFarm(&registry);

    try std.testing.expectEqual(@as(usize, 1), registry.assure(com.Player).dense.items.len);
    try std.testing.expectEqual(@as(usize, 1), registry.raw(com.Crop).len);
    try std.testing.expectEqual(@as(usize, 1), registry.raw(com.Farmland).len);
    try std.testing.expectEqual(@as(usize, 3), registry.raw(com.Render).len);
    try std.testing.expectEqual(@as(usize, 2), registry.assure(com.YSort).dense.items.len);
}
