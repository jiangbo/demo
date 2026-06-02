const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const Actor = component.actor.Actor;
const Animation = component.actor.Animation;
const Facing = component.actor.Facing;
const Sprite = component.render.Sprite;

pub fn update(world: *zhu.ecs.World, delta: f32) void {
    updateActor(world);

    var query = world.query(.{ Animation, Sprite });
    while (query.next()) |entity| {
        const animation = query.getPtr(entity, Animation);
        const sprite = query.getPtr(entity, Sprite);

        switch (animation.update(delta)) {
            .next, .loop => sprite.image = animation.subImage(),
            else => {},
        }
    }
}

fn updateActor(world: *zhu.ecs.World) void {
    var query = world.query(.{ Actor, Animation, Sprite });
    while (query.next()) |entity| {
        const actor = query.get(entity, Actor);
        const animation = query.getPtr(entity, Animation);
        const sprite = query.getPtr(entity, Sprite);

        const raw = actor.rows[@intFromEnum(actor.facing)];
        sprite.flip = raw < 0;
        std.debug.assert(raw != 0);
        const row: u8 = @intCast(@abs(raw) - 1);
        const index: u8 = @intFromEnum(actor.action);
        if (animation.sourceIndex != index or animation.row != row) {
            animation.playRow(index, row, true);
        }
    }
}

test "动画系统会按角色方向行更新精灵" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();

    const frames = [_]zhu.graphics.Frame{
        .{ .offset = .zero, .duration = 0.1 },
    };
    const image = zhu.Image{ .size = .xy(32, 32) };
    zhu.assets.putImage(1, image);

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Actor{ .action = .walk, .facing = .left });
    const sources = [_]zhu.Animation.Source{
        .{ .imageId = 1, .clip = &frames },
        .{ .imageId = 1, .clip = &frames },
    };
    world.add(entity, Animation.initSource(&sources, image.size));
    world.add(entity, Sprite{ .image = image });

    update(&world, 0);

    const sprite = world.get(entity, Sprite).?;
    try std.testing.expect(sprite.flip);
    try std.testing.expectEqual(64, sprite.image.offset.y);
}

test "负数行号表示翻转" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();

    const frames = [_]zhu.graphics.Frame{
        .{ .offset = .zero, .duration = 0.1 },
    };
    const image = zhu.Image{ .size = .xy(32, 32) };
    zhu.assets.putImage(1, image);

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Actor{
        .action = .idle,
        .facing = .right,
        .rows = .{ 1, 2, 3, -1 },
    });
    const sources = [_]zhu.Animation.Source{
        .{ .imageId = 1, .clip = &frames },
    };
    world.add(entity, Animation.initSource(&sources, image.size));
    world.add(entity, Sprite{ .image = image });

    update(&world, 0);

    const sprite = world.get(entity, Sprite).?;
    try std.testing.expect(sprite.flip);
    try std.testing.expectEqual(0, sprite.image.offset.y);
}
