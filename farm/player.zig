const zhu = @import("zhu");

const component = @import("component.zig");
const storage = @import("storage.zig");

const World = zhu.ecs.World;
const actor = component.actor;
const Position = component.Position;

pub fn capture(world: *World, mapId: component.map.Id) storage.Player {
    const entity = world.getIdentity(actor.Player).?;
    const position = world.get(entity, Position).?;
    const state = world.get(entity, actor.Actor) orelse actor.Actor{};

    return .{
        .map = mapId,
        .position = position,
        .facing = state.facing,
    };
}

pub fn restore(world: *World, data: storage.Player) void {
    const entity = world.getIdentity(actor.Player).?;
    const position = world.getPtr(entity, Position).?;
    const velocity = world.getPtr(entity, component.motion.Velocity).?;
    const target = world.getPtr(entity, component.ui.Target).?;
    const state = world.getPtr(entity, actor.Actor).?;

    position.* = data.position;
    velocity.value = .zero;
    target.active = false;
    state.action = .idle;
    state.facing = data.facing;
    world.remove(entity, actor.Busy);
    zhu.camera.directFollow(data.position);
}
