const ecs = @import("ecs");

const component = @import("../component.zig");
const Actor = component.Actor;
const Animation = component.Animation;

pub fn update(world: *ecs.World, delta: f32) void {
    var query = world.query(.{ Actor, Animation });
    while (query.next()) |entity| {
        const actor = query.get(entity, Actor);
        const animation = query.getPtr(entity, Animation);
        const sourceIndex: u8 = @intFromEnum(actor.facing);

        if (animation.sourceIndex != sourceIndex) {
            animation.play(sourceIndex);
        }
        _ = animation.update(delta);
    }
}
