const ecs = @import("ecs");

const component = @import("../component.zig");
const Animation = component.Animation;
const Facing = component.actor.Facing;
const Sprite = component.Sprite;
const WantMove = component.WantMove;

pub fn update(world: *ecs.World, delta: f32) void {
    var query = world.query(.{ Facing, Animation });
    while (query.next()) |entity| {
        const facing = query.get(entity, Facing);
        const animation = query.getPtr(entity, Animation);
        const sourceIndex: u8 = @intFromEnum(facing);

        var changed = animation.sourceIndex != sourceIndex;
        if (changed) animation.play(sourceIndex);
        if (world.has(entity, WantMove)) {
            if (animation.update(delta) != null) changed = true;
        }
        if (!changed) continue;
        world.getPtr(entity, Sprite).?.image = animation.subImage();
    }
}
