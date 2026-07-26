const std = @import("std");
const ecs = @import("ecs");

const component = @import("../component.zig");

const Collider = component.Collider;
const Player = component.actor.Player;
const Portal = component.Portal;
const Position = component.Position;

pub fn update(world: *ecs.World) void {
    world.removeIdentity(Portal);

    const player = world.getIdentity(Player).?;
    const position = world.get(player, Position).?;
    const collider = world.get(player, Collider).?;
    const center = collider.move(position).center();

    var query = world.query(.{Portal});
    while (query.next()) |entity| {
        const portal = query.get(entity, Portal);
        if (!portal.area.contains(center)) continue;
        world.addIdentity(entity, Portal);
        return;
    }
}

test "选择玩家当前所在的传送区域" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.addAll(player, .{
        Position.zero,
        Collider.init(.zero, .square(16)),
    });

    const portal = world.createEntity();
    world.add(portal, Portal{
        .key = .homeToCity,
        .area = .init(.zero, .square(32)),
    });

    update(&world);
    try std.testing.expectEqual(portal, world.getIdentity(Portal).?);

    world.add(player, Position.xy(32, 0));
    update(&world);
    try std.testing.expectEqual(null, world.getIdentity(Portal));
}
