const zhu = @import("zhu");

const component = @import("../component.zig");
const toolbar = @import("../toolbar.zig");

const Player = component.actor.Player;
const Position = component.Position;
const Pickup = component.item.Pickup;

const collectRadius: f32 = 12;

pub fn update(world: *zhu.ecs.World) void {
    const player = world.getIdentity(Player).?;
    const playerPos = world.get(player, Position).?;

    var query = world.query(.{ Pickup, Position }).reverse();
    while (query.next()) |entity| {
        const pickup = query.get(entity, Pickup);
        const position = query.get(entity, Position);
        const distance2 = position.sub(playerPos).length2();
        if (distance2 > collectRadius * collectRadius) continue;

        toolbar.add(pickup.item, pickup.count);
        world.destroyEntity(entity);
    }
}
