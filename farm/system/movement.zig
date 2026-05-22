const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const map = @import("../map.zig");

const Position = component.Position;
const Velocity = component.Velocity;
const Collider = component.Collider;

pub fn update(world: *zhu.ecs.World, delta: f32) void {
    var query = world.query(.{ Position, Velocity });
    while (query.next()) |entity| {
        const velocity = query.get(entity, Velocity);
        const position = query.getPtr(entity, Position);
        const offset = velocity.value.scale(delta);

        const collider = world.get(entity, Collider);
        if (collider) |c| {
            // 轴分离碰撞解析：先尝试 X 轴移动，再尝试 Y 轴移动
            // 碰撞时回退到原始坐标，这样可以沿墙滑动而不会卡死
            var pos = position.*;
            pos.x += offset.x;
            if (map.isSolid(pos, c)) pos.x = position.x;
            pos.y += offset.y;
            if (map.isSolid(pos, c)) pos.y = position.y;

            position.* = pos;
        } else {
            position.* = position.add(offset);
        }
    }
}

test "移动系统会按速度更新位置" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Position.xy(10, 20));
    world.add(entity, Velocity{ .value = .xy(3, -4) });

    update(&world, 0.5);

    const position = world.get(entity, Position).?;
    try std.testing.expect(position.approxEqual(.xy(11.5, 18)));
}

test "有 Collider 的实体会被 solid 格子阻挡" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    const count = map.data.width * map.data.height;
    map.solids = zhu.assets.oomAlloc(bool, count);
    defer zhu.assets.free(map.solids);
    @memset(map.solids, false);

    // 标记 tile (2,2) 为 solid（世界坐标 32~48, 32~48）
    map.solids[map.data.worldToTileIndex(.xy(40, 40)).?] = true;

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    // 实体在 (56, 40)，碰撞框 (51,34)~(61,40)，不与 solid 重叠
    // 向左移动 20：碰撞框变成 (31,34)~(41,40)，与 solid(32~48,32~48) 重叠
    const entity = world.createEntity();
    world.add(entity, Position.xy(56, 40));
    world.add(entity, Velocity{ .value = .xy(-20, 0) });
    world.add(entity, Collider{ .size = .xy(10, 6), .offset = .xy(-5, -6) });

    update(&world, 1.0);

    // 向左移动会碰到 solid 格子，x 应被阻挡
    const position = world.get(entity, Position).?;
    try std.testing.expectEqual(@as(f32, 56), position.x);
}

test "有 Collider 的实体会被 solid 格子垂直阻挡" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    const count = map.data.width * map.data.height;
    map.solids = zhu.assets.oomAlloc(bool, count);
    defer zhu.assets.free(map.solids);
    @memset(map.solids, false);

    // 标记 tile (2,2) 为 solid（世界坐标 32~48, 32~48）
    map.solids[map.data.worldToTileIndex(.xy(40, 40)).?] = true;

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Position.xy(40, 60));
    world.add(entity, Velocity{ .value = .xy(0, -20) });
    world.add(entity, Collider{ .size = .xy(10, 6), .offset = .xy(-5, -6) });

    update(&world, 1.0);

    const position = world.get(entity, Position).?;
    try std.testing.expectEqual(@as(f32, 60), position.y);
}

test "斜向撞墙时未碰撞轴仍会滑动" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    const count = map.data.width * map.data.height;
    map.solids = zhu.assets.oomAlloc(bool, count);
    defer zhu.assets.free(map.solids);
    @memset(map.solids, false);

    // 标记 tile (2,2) 为 solid（世界坐标 32~48, 32~48）
    map.solids[map.data.worldToTileIndex(.xy(40, 40)).?] = true;

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Position.xy(56, 40));
    world.add(entity, Velocity{ .value = .xy(-20, 5) });
    world.add(entity, Collider{ .size = .xy(10, 6), .offset = .xy(-5, -6) });

    update(&world, 1.0);

    const position = world.get(entity, Position).?;
    try std.testing.expectEqual(@as(f32, 56), position.x);
    try std.testing.expectEqual(@as(f32, 45), position.y);
}
