const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const map = @import("../map.zig");

const Collider = component.Collider;
const Position = component.Position;
const Speed = component.Speed;
const WantMove = component.WantMove;

// 移动系统本帧计算出的目标位置。
const MoveTo = struct { value: zhu.Vector2 };

pub fn update(world: *ecs.World, delta: f32) void {
    world.clear(MoveTo);
    prepareMove(world, delta);
    updateMove(world);
}

fn prepareMove(world: *ecs.World, delta: f32) void {
    // 根据移动意图计算本帧的目标位置。
    var query = world.query(.{ Position, Speed, WantMove });
    while (query.next()) |entity| {
        const position = query.get(entity, Position);
        const speed = query.get(entity, Speed);
        const wantMove = query.get(entity, WantMove);
        const offset = wantMove.value.scale(speed.value * delta);
        world.add(entity, MoveTo{
            .value = position.add(offset),
        });
    }
}

fn updateMove(world: *ecs.World) void {
    // 检查碰撞后应用真正允许到达的位置。
    var query = world.query(.{ Position, Collider, MoveTo });
    blk: while (query.next()) |entity| {
        const position = query.getPtr(entity, Position);
        const collider = query.get(entity, Collider);
        const moveTo = query.get(entity, MoveTo);
        const area = collider.rect(position.*);
        const offset = moveTo.value.sub(position.*);
        const min = map.walkTo(area, offset);
        const target = collider.position(min);
        const moveArea = collider.rect(target);

        var others = world.query(.{ Position, Collider });
        while (others.next()) |other| {
            if (other == entity) continue;

            const otherPosition = others.get(other, Position);
            const otherCollider = others.get(other, Collider);
            const otherArea = otherCollider.rect(otherPosition);
            if (moveArea.intersect(otherArea)) continue :blk;
        }
        position.* = target;
    }
}
