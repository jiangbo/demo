const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const input = @import("../input.zig");

const Collider = component.Collider;
const Facing = component.Facing;
const Player = component.Player;
const Position = component.Position;
const Talk = component.Talk;
const WantMove = component.WantMove;

pub fn update(world: *ecs.World) void {
    if (world.getIdentity(Talk) != null) return;
    if (!input.released(.confirm)) return;

    const entity = nearestEntity(world) orelse return;

    const player = world.getIdentity(Player).?;
    const facing = world.get(player, Facing).?;
    world.add(entity, switch (facing) {
        .down => Facing.up,
        .left => Facing.right,
        .up => Facing.down,
        .right => Facing.left,
    });
    world.remove(entity, WantMove);
    world.addIdentity(entity, Talk);
}

// 获取玩家对话区域内距离中心最近的实体。
fn nearestEntity(world: *ecs.World) ?ecs.Entity {
    const area = getPlayerArea(world);
    var nearest: ?ecs.Entity = null;
    var distance2 = std.math.inf(f32);
    var query = world.query(.{ Position, Collider, Talk });
    while (query.next()) |entity| {
        const position = query.get(entity, Position);
        const collider = query.get(entity, Collider);
        const targetArea = collider.move(position);
        if (!area.intersect(targetArea)) continue;

        const d2 = area.center().sub(targetArea.center()).length2();
        if (d2 >= distance2) continue;
        nearest = entity;
        distance2 = d2;
    }
    return nearest;
}

// 从玩家碰撞区域的中心向当前朝向生成对话区域。
fn getPlayerArea(world: *ecs.World) zhu.Rect {
    const player = world.getIdentity(Player).?;
    const position = world.get(player, Position).?;
    const collider = world.get(player, Collider).?;
    const facing = world.get(player, Facing).?;

    const center = collider.move(position).center();
    const size = zhu.Vector2.xy(32, 32);
    const min = switch (facing) {
        .down => center.addXY(-size.x * 0.5, 0),
        .left => center.addXY(-size.x, -size.y * 0.5),
        .up => center.addXY(-size.x * 0.5, -size.y),
        .right => center.addXY(0, -size.y * 0.5),
    };
    return .init(min, size);
}

test "选择玩家正前方最近的对话对象" {
    zhu.input.reset();
    defer zhu.input.reset();

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.addAll(player, .{
        Position.zero,
        Collider.init(.xy(-8, -16), .xy(16, 16)),
        Facing.down,
    });

    const near = world.createEntity();
    world.addAll(near, .{
        Position.xy(0, 32),
        Collider.init(.xy(-8, -16), .xy(16, 16)),
        Facing.down,
        Talk{},
        WantMove{ .value = .xy(0, 1) },
    });

    const far = world.createEntity();
    world.addAll(far, .{
        Position.xy(0, 48),
        Collider.init(.xy(-8, -16), .xy(16, 16)),
        Facing.down,
        Talk{},
    });

    zhu.key.set(.F, true);
    zhu.input.update();
    zhu.key.set(.F, false);
    update(&world);

    try std.testing.expectEqual(near, world.getIdentity(Talk).?);
    try std.testing.expectEqual(Facing.up, world.get(near, Facing).?);
    try std.testing.expect(!world.has(near, WantMove));
}

test "使用 NPC 碰撞区域检测对话" {
    zhu.input.reset();
    defer zhu.input.reset();

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.addAll(player, .{
        Position.zero,
        Collider.init(.xy(-8, -16), .xy(16, 16)),
        Facing.down,
    });

    const target = world.createEntity();
    world.addAll(target, .{
        Position.xy(0, 36),
        Collider.init(.xy(-8, -16), .xy(16, 16)),
        Facing.down,
        Talk{},
    });

    zhu.key.set(.F, true);
    zhu.input.update();
    zhu.key.set(.F, false);
    update(&world);

    try std.testing.expectEqual(target, world.getIdentity(Talk).?);
}
