const zhu = @import("zhu");

const component = @import("../component.zig");
const context = @import("../context.zig");
const Trigger = component.map.Trigger;

pub fn update(world: *zhu.ecs.World) void {
    const player = world.getIdentity(component.actor.Player).?;
    const position = world.get(player, component.Position).?;

    var query = world.query(.{Trigger});
    while (query.next()) |entity| {
        const trigger = query.get(entity, Trigger);
        if (trigger.rect.contains(position)) {
            context.map.pending = .{
                .target = trigger.targetMap,
                .targetId = trigger.selfId,
            };
            return;
        }
    }
}
