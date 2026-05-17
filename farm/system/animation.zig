const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const Actor = component.Actor;
const Animation = component.Animation;
const Facing = component.Facing;
const Sprite = component.Sprite;

pub fn update(world: *zhu.ecs.World, delta: f32) void {
    updateActors(world);

    var query = world.query(.{ Animation, Sprite });
    while (query.next()) |entity| {
        const animation = query.getPtr(entity, Animation);
        const sprite = query.getPtr(entity, Sprite);

        switch (animation.update(delta)) {
            .next, .loop => {
                const size = sprite.size orelse sprite.image.size;
                sprite.image = animation.subImage(size);
            },
            else => {},
        }
    }
}

const FacingFrame = struct {
    row: u8,
    flip: bool = false,
};

fn updateActors(world: *zhu.ecs.World) void {
    var query = world.query(.{ Actor, Animation, Sprite });
    while (query.next()) |entity| {
        const actor = query.get(entity, Actor);
        const animation = query.getPtr(entity, Animation);
        const sprite = query.getPtr(entity, Sprite);

        const facing = resolveFacing(actor.directions, actor.facing);
        const index: u8 = @intFromEnum(actor.animation);
        if (animation.sourceIndex != index) {
            animation.playRow(index, facing.row, true);
        } else if (animation.row != facing.row) {
            animation.row = facing.row;
            animation.reset();
        }

        sprite.flip = facing.flip;
    }
}

fn resolveFacing(directions: []const Facing, facing: Facing) FacingFrame {
    if (findFacing(directions, facing)) |row| return .{ .row = row };

    switch (facing) {
        .left => {
            if (findFacing(directions, .right)) |row| {
                return .{ .row = row, .flip = true };
            }
        },
        .right => {
            if (findFacing(directions, .left)) |row| {
                return .{ .row = row, .flip = true };
            }
        },
        else => {},
    }

    if (findFacing(directions, .down)) |row| return .{ .row = row };
    return .{ .row = 0 };
}

fn findFacing(directions: []const Facing, facing: Facing) ?u8 {
    for (directions, 0..) |item, row| {
        if (item == facing) return @intCast(row);
    }
    return null;
}

test "动画系统会按角色方向行更新精灵" {
    const frames = [_]zhu.graphics.Frame{
        .{ .offset = .zero, .duration = 0.1 },
    };
    const image = zhu.graphics.Image{
        .texture = .{ .id = 1 },
        .size = .xy(32, 32),
    };

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Actor{ .animation = .walk, .facing = .left });
    world.add(entity, Animation{
        .image = image,
        .clip = &frames,
        .sourceIndex = @intFromEnum(component.PlayerAnimation.walk),
    });
    world.add(entity, Sprite{ .image = image });

    update(&world, 0);

    const sprite = world.get(entity, Sprite).?;
    try std.testing.expect(sprite.flip);
    try std.testing.expectEqual(@as(f32, 64), sprite.image.offset.y);
}

test "三方向配置可以镜像缺失的水平朝向" {
    const directions = [_]Facing{ .left, .down, .up };
    const facing = resolveFacing(&directions, .right);

    try std.testing.expectEqual(@as(u8, 0), facing.row);
    try std.testing.expect(facing.flip);
}
