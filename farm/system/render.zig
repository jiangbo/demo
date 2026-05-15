const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");

pub fn draw(registry: *zhu.ecs.Registry) void {
    registry.sort(com.Render, lessThan);

    var query = registry.view(.{ com.Render, com.Position, com.Sprite });
    const renders = query.query(com.Render);
    const positions = query.query(com.Position);
    const sprites = query.query(com.Sprite);
    while (query.next()) |entity| {
        const render = renders.get(entity);
        const position = positions.get(entity);
        const sprite = sprites.get(entity);

        zhu.batch.drawImage(sprite.image, position.add(sprite.offset), .{
            .size = sprite.size,
            .color = render.color,
            .mask = .{ .flipX = sprite.flip },
        });
    }
}

pub fn lessThan(lhs: com.Render, rhs: com.Render) bool {
    if (lhs.layer == rhs.layer) return lhs.depth < rhs.depth;
    return @intFromEnum(lhs.layer) < @intFromEnum(rhs.layer);
}

test "Render 排序先比较图层再比较深度" {
    const ground = com.Render{ .layer = .ground, .depth = 100 };
    const crop = com.Render{ .layer = .crop, .depth = 0 };
    const actorBack = com.Render{ .layer = .actor, .depth = 8 };
    const actorFront = com.Render{ .layer = .actor, .depth = 16 };

    try std.testing.expect(lessThan(ground, crop));
    try std.testing.expect(lessThan(actorBack, actorFront));
    try std.testing.expect(!lessThan(actorFront, actorBack));
}
