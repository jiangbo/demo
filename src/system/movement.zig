const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const map = @import("../map.zig");

const Collider = component.Collider;
const Position = component.Position;
const Speed = component.Speed;
const WantMove = component.WantMove;

// 移动系统本帧计算出的位移。
const Move = struct { offset: zhu.Vector2 };

pub fn update(world: *ecs.World, delta: f32) void {
    prepareMove(world, delta);
    updateMove(world);
    world.clear(Move);
}

fn prepareMove(world: *ecs.World, delta: f32) void {
    // 根据移动意图计算本帧位移。
    var query = world.query(.{ Position, Speed, WantMove });
    while (query.next()) |entity| {
        const speed = query.get(entity, Speed);
        const wantMove = query.get(entity, WantMove);
        const offset = wantMove.value.scale(speed.value * delta);
        world.add(entity, Move{ .offset = offset });
    }
}

fn updateMove(world: *ecs.World) void {
    // 检查碰撞后应用真正允许到达的位置。
    var query = world.query(.{ Position, Collider, Move });
    move: while (query.next()) |entity| {
        const position = query.getPtr(entity, Position);
        const collider = query.get(entity, Collider);
        const move = query.get(entity, Move);

        // 先将本帧位移限制在可通过的地图瓦片内。
        const area = collider.move(position.*);
        const moved = map.walk(area, move.offset);

        // 与任一实体重叠时，放弃本帧移动。
        var others = world.query(.{ Position, Collider });
        while (others.next()) |other| {
            if (other == entity) continue;

            const otherPosition = others.get(other, Position);
            const otherCollider = others.get(other, Collider);
            const otherArea = otherCollider.move(otherPosition);
            if (moved.intersect(otherArea)) continue :move;
        }

        // 将碰撞区域位置还原为实体的逻辑位置。
        position.* = moved.min.sub(collider.min);
    }
}
