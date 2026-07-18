const ecs = @import("ecs");
const zhu = @import("zhu");

const component = @import("../component.zig");
const Animation = component.Animation;
const Position = component.Position;
const RenderOffset = component.RenderOffset;

pub fn draw(world: *ecs.World) void {
    world.sort(Position, lessY);

    var query = world.queryBy(Position, .{Animation}, .{});
    while (query.next()) |entity| {
        var position = query.get(entity, Position);
        const animation = query.get(entity, Animation);
        if (world.get(entity, RenderOffset)) |offset| {
            position = position.add(offset.value);
        }
        zhu.batch.drawImage(animation.subImage(), position, .{
            .anchor = .xy(0.5, 1),
        });
    }
}

fn lessY(lhs: Position, rhs: Position) bool {
    return lhs.y < rhs.y;
}
