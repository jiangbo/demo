const ecs = @import("ecs");
const zhu = @import("zhu");

const component = @import("../component.zig");
const Position = component.Position;
const Sprite = component.Sprite;

pub fn draw(world: *ecs.World) void {
    world.sort(Position, lessY);

    var query = world.queryBy(Position, .{Sprite}, .{});
    while (query.next()) |entity| {
        const position = query.get(entity, Position);
        const sprite = query.get(entity, Sprite);
        zhu.batch.drawImage(sprite.image, position, .{
            .anchor = sprite.anchor,
        });
    }
}

fn lessY(lhs: Position, rhs: Position) bool {
    return lhs.y < rhs.y;
}
