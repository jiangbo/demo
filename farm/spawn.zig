const std = @import("std");
const zhu = @import("zhu");

const com = @import("component.zig");

pub fn init() void {
    std.log.info("spawn init", .{});
}

pub fn deinit() void {}

pub fn loadFarm(World: *zhu.ecs.World) void {
    const player = World.createEntity();
    World.add(player, com.Player{});
    World.add(player, com.Position.xy(160, 96));
    World.add(player, com.Sprite{
        .image = zhu.batch.whiteImage,
        .offset = .xy(-6, -18),
        .size = .xy(12, 18),
    });
    World.add(player, com.Render{
        .layer = .actor,
        .color = .rgb(0.92, 0.82, 0.64),
    });
    World.add(player, com.YSort{});

    const crop = World.createEntity();
    World.add(crop, com.Crop{ .growth = 0 });
    World.add(crop, com.Position.xy(176, 96));
    World.add(crop, com.Sprite{
        .image = zhu.batch.whiteImage,
        .offset = .xy(-6, -10),
        .size = .xy(12, 10),
    });
    World.add(crop, com.Render{
        .layer = .crop,
        .color = .rgb(0.24, 0.68, 0.28),
    });
    World.add(crop, com.YSort{});

    const farmland = World.createEntity();
    World.add(farmland, com.Farmland{});
    World.add(farmland, com.Position.xy(176, 112));
    World.add(farmland, com.Sprite{
        .image = zhu.batch.whiteImage,
        .offset = .xy(-8, -8),
        .size = .xy(16, 16),
    });
    World.add(farmland, com.Render{
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
    var World = zhu.ecs.World.init(std.testing.allocator);
    defer World.deinit();

    loadFarm(&World);

    try std.testing.expectEqual(@as(usize, 1), World.assure(com.Player).dense.items.len);
    try std.testing.expectEqual(@as(usize, 1), World.raw(com.Crop).len);
    try std.testing.expectEqual(@as(usize, 1), World.raw(com.Farmland).len);
    try std.testing.expectEqual(@as(usize, 3), World.raw(com.Render).len);
    try std.testing.expectEqual(@as(usize, 2), World.assure(com.YSort).dense.items.len);
}
