const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");

const playerIdlePath =
    "assets/farm-rpg/Character and Portrait/Character/Pre-made/Alex/Idle.png";
const playerFrameSize = zhu.Vector2.xy(32, 32);

var playerIdleFrame: ?zhu.graphics.Image = null;

pub fn init() void {
    const image = zhu.assets.loadImage(playerIdlePath);
    playerIdleFrame = image.sub(.init(.zero, playerFrameSize));
    std.log.info("spawn init", .{});
}

pub fn deinit() void {
    playerIdleFrame = null;
}

pub fn loadFarm(world: *zhu.ecs.World) void {
    const player = world.createEntity();
    world.add(player, component.Player{});
    world.add(player, component.Position.xy(160, 96));
    world.add(player, component.Sprite{
        .image = playerIdleFrame orelse zhu.batch.whiteImage,
        .offset = .xy(-16, -24),
        .size = playerFrameSize,
    });
    world.add(player, component.Render{
        .layer = .actor,
    });
    world.add(player, component.YSort{});

    const crop = world.createEntity();
    world.add(crop, component.Crop{ .growth = 0 });
    world.add(crop, component.Position.xy(176, 96));
    world.add(crop, component.Sprite{
        .image = zhu.batch.whiteImage,
        .offset = .xy(-6, -10),
        .size = .xy(12, 10),
    });
    world.add(crop, component.Render{
        .layer = .crop,
        .color = .rgb(0.24, 0.68, 0.28),
    });
    world.add(crop, component.YSort{});

    const farmland = world.createEntity();
    world.add(farmland, component.Farmland{});
    world.add(farmland, component.Position.xy(176, 112));
    world.add(farmland, component.Sprite{
        .image = zhu.batch.whiteImage,
        .offset = .xy(-8, -8),
        .size = .xy(16, 16),
    });
    world.add(farmland, component.Render{
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
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    loadFarm(&world);

    const equal = std.testing.expectEqual;
    try equal(1, world.assure(component.Player).dense.items.len);
    try equal(1, world.raw(component.Crop).len);
    try equal(1, world.raw(component.Farmland).len);
    try equal(3, world.raw(component.Render).len);
    try equal(2, world.assure(component.YSort).dense.items.len);
}
