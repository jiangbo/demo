const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const map = @import("../map.zig");
const spawn = @import("../spawn.zig");

const Crop = component.Crop;
const Farmland = component.Farmland;
const Position = component.Position;

pub fn hoe(world: *zhu.ecs.World, position: zhu.Vector2) void {
    if (hasComponentAt(world, Farmland, position)) return;
    if (hasComponentAt(world, Crop, position)) return;

    spawn.farmland(world, position);
}

fn hasComponentAt(
    world: *zhu.ecs.World,
    comptime T: type,
    tilePosition: zhu.Vector2,
) bool {
    const targetTile = map.data.worldToTilePosition(tilePosition);
    var query = world.query(.{ Position, T });
    while (query.next()) |entity| {
        const position = query.get(entity, Position);
        const entityTile = map.data.worldToTilePosition(position);
        if (entityTile.x == targetTile.x and entityTile.y == targetTile.y) {
            return true;
        }
    }
    return false;
}

test "锄地会在目标格创建耕地" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockImage();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    hoe(&world, .xy(32, 48));
    try std.testing.expectEqual(1, world.raw(Farmland).len);
}

test "已有耕地时不会重复锄地" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockImage();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    hoe(&world, .xy(32, 48));
    hoe(&world, .xy(32, 48));
    try std.testing.expectEqual(1, world.raw(Farmland).len);
}

test "目标格有作物时不会锄地" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockImage();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const crop = world.createEntity();
    world.add(crop, Crop{});
    world.add(crop, Position.xy(40, 56));

    hoe(&world, .xy(32, 48));
    try std.testing.expectEqual(0, world.raw(Farmland).len);
}

fn putMockImage() void {
    const template = @import("../template.zig");
    const image = zhu.graphics.Image{
        .texture = .{ .id = 1 },
        .size = .xy(256, 256),
    };

    const id = zhu.assets.id(template.farm.farmland.sprite.path);
    zhu.assets.putImage(id, image);
}
