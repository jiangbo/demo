const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");

const Collider = component.Collider;
const Map = component.map.Map;
const Position = component.Position;
const Speed = component.Speed;
const Static = component.map.Static;
const Vector2 = zhu.Vector2;
const WantMove = component.WantMove;

// 移动系统本帧计算出的目标位置。
const MoveTo = struct { value: Vector2 };

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
    const mapEntity = world.getIdentity(Map).?;
    const field = world.get(mapEntity, Static).?;
    var query = world.query(.{ Position, Collider, MoveTo });
    blk: while (query.next()) |entity| {
        const position = query.getPtr(entity, Position);
        const collider = query.get(entity, Collider);
        const moveTo = query.get(entity, MoveTo);
        const area = collider.move(position.*);
        const offset = moveTo.value.sub(position.*);
        const moveMin = walkTo(field, area, offset);
        const target = moveMin.sub(collider.min);
        const moveArea = collider.move(target);

        var others = world.query(.{ Position, Collider });
        while (others.next()) |other| {
            if (other == entity) continue;

            const otherPosition = others.get(other, Position);
            const otherCollider = others.get(other, Collider);
            const otherArea = otherCollider.move(otherPosition);
            if (moveArea.intersect(otherArea)) continue :blk;
        }
        position.* = target;
    }
}

fn walkTo(field: Static, area: zhu.Rect, velocity: Vector2) Vector2 {
    var moved = area;
    moved.min.x = limit(field.scanX(moved, velocity.x));
    moved.min.y = limit(field.scanY(moved, velocity.y));
    return moved.min;
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

    const area = zhu.Rect.init(.xy(40, 40), .square(16));

    var moved = walkTo(field, area, .xy(20, 0));
    try std.testing.expectEqual(@as(f32, 48), moved.x);
    try std.testing.expectEqual(@as(f32, 40), moved.y);

    moved = walkTo(field, area, .xy(-20, 0));
    try std.testing.expectEqual(@as(f32, 32), moved.x);

    moved = walkTo(field, area, .xy(0, 20));
    try std.testing.expectEqual(@as(f32, 48), moved.y);

    moved = walkTo(field, area, .xy(0, -20));
    try std.testing.expectEqual(@as(f32, 32), moved.y);

    const passable = [_]u8{
        1, 1, 1,
        1, 0, 5,
        1, 1, 1,
    };
    field.data = &passable;
    moved = walkTo(field, area, .xy(20, 0));
    try std.testing.expectEqual(@as(f32, 60), moved.x);
}
