const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const template = @import("template.zig");

pub fn init() void {
    std.log.info("spawn init", .{});
}

pub fn loadFarm(world: *zhu.ecs.World) void {
    spawnPlayer(world);
}

fn spawnPlayer(world: *zhu.ecs.World) void {
    const config = template.actor.player;

    const player = world.createIdentityEntity(component.Player);
    world.add(player, component.Position.xy(160, 96));
    world.add(player, component.Velocity{});
    world.add(player, component.Actor{ .rows = config.rows });

    const sources = comptime animationSources(config.animations);
    const animation = zhu.Animation.initSource(&sources);

    world.add(player, component.Sprite{
        .image = animation.image,
        .offset = config.sprite.offset,
        .size = config.sprite.size,
    });

    world.add(player, animation);
    world.add(player, component.Render{ .layer = .actor });
    world.add(player, component.YSort{});
    world.add(player, component.Target{});
}

fn animationSources(comptime animations: []const template.Animation) //
[animations.len]zhu.Animation.Source {
    var sources: [animations.len]zhu.Animation.Source = undefined;
    inline for (animations) |config| {
        sources[@intFromEnum(config.type)] = .{
            .imageId = zhu.assets.id(config.path),
            .clip = config.frames,
        };
    }
    return sources;
}

fn spriteImage(comptime sprite: anytype) zhu.graphics.Image {
    const rect = sprite.rect;

    if (zhu.getImage(sprite.path)) |source| return source.sub(rect);
    return zhu.batch.whiteImage.sub(rect);
}

test "加载农场会创建初始实体" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockFarmImages();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    loadFarm(&world);

    const equal = std.testing.expectEqual;
    const player = world.getIdentityEntity(component.Player).?;
    try equal(160, world.get(player, component.Position).?.x);
    try equal(1, world.raw(component.Velocity).len);
    try equal(1, world.raw(component.Actor).len);
    try equal(1, world.raw(component.Sprite).len);
    try equal(1, world.raw(component.Render).len);
    try equal(1, world.assure(component.YSort).dense.items.len);
}

fn putMockFarmImages() void {
    const image = zhu.graphics.Image{
        .texture = .{ .id = 1 },
        .size = .xy(256, 256),
    };

    inline for (template.actor.player.animations) |animation| {
        zhu.assets.putImage(zhu.assets.id(animation.path), image);
    }
}
