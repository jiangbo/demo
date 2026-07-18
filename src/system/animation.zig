const ecs = @import("ecs");

const component = @import("../component.zig");
const Animation = component.Animation;
const Facing = component.Facing;
const WantMove = component.WantMove;

pub fn update(world: *ecs.World, delta: f32) void {
    var query = world.query(.{ Facing, Animation });
    while (query.next()) |entity| {
        const facing = query.get(entity, Facing);
        const animation = query.getPtr(entity, Animation);
        const sourceIndex: u8 = @intFromEnum(facing);

        if (animation.sourceIndex != sourceIndex) {
            animation.play(sourceIndex);
        }
        if (!world.has(entity, WantMove)) continue;
        _ = animation.update(delta);
    }
}
