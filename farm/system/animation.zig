const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const Animation = component.Animation;
const Sprite = component.Sprite;

pub fn update(world: *zhu.ecs.World, delta: f32) void {
    var query = world.query(.{ Animation, Sprite });
    while (query.next()) |entity| {
        const animation = query.getPtr(entity, Animation);
        const sprite = query.getPtr(entity, Sprite);

        switch (animation.update(delta)) {
            .next, .loop => {
                sprite.image = animation.subImage(sprite.image.size);
            },
            else => {},
        }
    }
}
