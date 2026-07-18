const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const map = @import("../map.zig");

const Actor = component.Actor;
const Collider = component.Collider;
const Speed = component.Speed;
const WantMove = component.WantMove;

// 移动系统本帧计算出的目标位置。
const MoveTo = struct {
    value: zhu.Vector2,
};

pub fn update(world: *ecs.World, delta: f32) void {
    world.clear(MoveTo);
    prepareMove(world, delta);
    updateMove(world);
}

fn prepareMove(world: *ecs.World, delta: f32) void {
    // 根据移动意图计算本帧的目标位置。
    var query = world.query(.{ Actor, Speed, WantMove });
    while (query.next()) |entity| {
        const actor = query.get(entity, Actor);
        const speed = query.get(entity, Speed);
        const wantMove = query.get(entity, WantMove);
        const offset = wantMove.value.scale(speed.value * delta);
        world.add(entity, MoveTo{
            .value = actor.position.add(offset),
        });
    }
}

fn updateMove(world: *ecs.World) void {
    // 检查碰撞后应用真正允许到达的位置。
    var query = world.query(.{ Actor, Collider, MoveTo });
    blk: while (query.next()) |entity| {
        const actor = query.getPtr(entity, Actor);
        const collider = query.get(entity, Collider);
        const moveTo = query.get(entity, MoveTo);
        const area = collider.rect(actor.position);
        const offset = moveTo.value.sub(actor.position);
        const min = map.walkTo(area, offset);
        const position = collider.position(min);
        const moveArea = collider.rect(position);

        var others = world.query(.{ Actor, Collider });
        while (others.next()) |other| {
            if (other == entity) continue;

            const otherActor = others.get(other, Actor);
            const otherCollider = others.get(other, Collider);
            const otherArea = otherCollider.rect(otherActor.position);
            if (moveArea.intersect(otherArea)) continue :blk;
        }
        actor.position = position;
    }
}
