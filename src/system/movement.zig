const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");

const Collider = component.Collider;
const Map = component.map.Map;
const Position = component.Position;
const Rect = zhu.Rect;
const Speed = component.Speed;
const Static = component.map.Static;
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
    // 所有移动实体共用当前地图的静态碰撞数据。
    const mapEntity = world.getIdentity(Map).?;
    const field = world.get(mapEntity, Static).?;
    var query = world.query(.{ Position, Collider, Move });
    move: while (query.next()) |entity| {
        const position = query.getPtr(entity, Position);
        const collider = query.get(entity, Collider);
        const move = query.get(entity, Move);

        // 先将本帧位移限制在可通过的地图瓦片内。
        const area = collider.move(position.*);
        const moved = walkTo(field, area, move.offset);

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

fn walkTo(field: Static, area: Rect, velocity: zhu.Vector2) Rect {
    var moved = area;
    moved.min.x = limit(field.scanX(moved, velocity.x));
    moved.min.y = limit(field.scanY(moved, velocity.y));
    return moved;
}

// 当前地图采用碰撞后移动到瓦片边缘的策略。
fn limit(scanValue: zhu.extend.tiled.Scan(u8)) f32 {
    var scan = scanValue;
    while (scan.next()) |value| {
        switch (value) {
            1, 3, 4 => return scan.touch,
            else => continue,
        }
    }
    return scan.dest;
}

test "地图瓦片移动" {
    const objects = [_]u8{
        1, 1, 1,
        1, 0, 1,
        1, 1, 1,
    };
    var field = Static{
        .grid = .{ .width = 3, .height = 3, .cell = 32 },
        .data = &objects,
    };

    const area = Rect.init(.xy(40, 40), .square(16));

    var moved = walkTo(field, area, .xy(20, 0));
    try std.testing.expectEqual(48, moved.min.x);
    try std.testing.expectEqual(40, moved.min.y);

    moved = walkTo(field, area, .xy(-20, 0));
    try std.testing.expectEqual(32, moved.min.x);

    moved = walkTo(field, area, .xy(0, 20));
    try std.testing.expectEqual(48, moved.min.y);

    moved = walkTo(field, area, .xy(0, -20));
    try std.testing.expectEqual(32, moved.min.y);

    const passable = [_]u8{
        1, 1, 1,
        1, 0, 5,
        1, 1, 1,
    };
    field.data = &passable;
    moved = walkTo(field, area, .xy(20, 0));
    try std.testing.expectEqual(60, moved.min.x);
}
