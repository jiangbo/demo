const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const Position = component.Position;
const Render = component.Render;
const Sprite = component.Sprite;

pub fn draw(world: *zhu.ecs.World) void {
    world.sort(Render, lessThan);

    var query = world.query(.{ Render, Position, Sprite });
    while (query.next()) |entity| {
        const render = query.get(entity, Render);
        const position = query.get(entity, Position);
        const sprite = query.get(entity, Sprite);

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
