const ecs = @import("ecs");
const zhu = @import("zhu");

const component = @import("../component.zig");
const Actor = component.Actor;
const Animation = component.Animation;

pub fn draw(world: *ecs.World) void {
    var query = world.query(.{ Actor, Animation });
    while (query.next()) |entity| {
        const actor = query.get(entity, Actor);
        const animation = query.get(entity, Animation);
        zhu.batch.drawImage(animation.subImage(), actor.position, .{
            .anchor = .xy(0.5, 1),
        });
    }
}
