const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const Position = component.Position;
const Render = component.Render;
const Sprite = component.Sprite;

pub fn draw(world: *zhu.ecs.World) void {
    world.sort(Render, lessThan);

    var view = world.view(.{ Render, Position, Sprite });
    while (view.next()) |entity| {
        const render = view.query(Render).get(entity);
        const position = view.query(Position).get(entity);
        const sprite = view.query(Sprite).get(entity);

        zhu.batch.drawImage(sprite.image, position.add(sprite.offset), .{
            .size = sprite.size,
            .color = render.color,
            .mask = .{ .flipX = sprite.flip },
        });
    }
}

pub fn lessThan(lhs: Render, rhs: Render) bool {
    if (lhs.layer == rhs.layer) return lhs.depth < rhs.depth;
    return @intFromEnum(lhs.layer) < @intFromEnum(rhs.layer);
}

test "渲染排序先比较图层再比较深度" {
    const ground = Render{ .layer = .ground, .depth = 100 };
    const crop = Render{ .layer = .crop, .depth = 0 };
    const actorBack = Render{ .layer = .actor, .depth = 8 };
    const actorFront = Render{ .layer = .actor, .depth = 16 };

    try std.testing.expect(lessThan(ground, crop));
    try std.testing.expect(lessThan(actorBack, actorFront));
    try std.testing.expect(!lessThan(actorFront, actorBack));
}
