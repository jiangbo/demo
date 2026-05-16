const zhu = @import("zhu");
const component = @import("../component.zig");
const Animation = component.Animation;
const Sprite = component.Sprite;

pub fn update(world: *zhu.ecs.World, delta: f32) void {
    var query = world.query(.{ Animation, Sprite });
    while (query.next()) |entity| {
        const anim = query.getPtr(entity, Animation);
        const sprite = query.getPtr(entity, Sprite);

        switch (anim.update(delta)) {
            .next, .loop => {
                sprite.image = anim.subImage(sprite.image.size);
            },
            else => {},
        }
    }
}
