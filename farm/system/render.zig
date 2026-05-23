const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const Position = component.Position;
const Render = component.render.Render;
const Sprite = component.render.Sprite;

pub fn draw(world: *zhu.ecs.World) void {
    world.sort(Render, lessThan);

    const viewport = zhu.camera.viewport();
    var query = world.query(.{ Render, Position, Sprite });
    while (query.next()) |entity| {
        const render = query.get(entity, Render);
        const position = query.get(entity, Position);
        const sprite = query.get(entity, Sprite);

        const spriteSize = sprite.size orelse sprite.image.size;
        const spritePosition = position.add(sprite.offset);
        const spriteRect = zhu.Rect.init(spritePosition, spriteSize);
        if (!viewport.intersect(spriteRect)) continue;
        zhu.batch.drawImage(sprite.image, position.add(sprite.offset), .{
            .size = sprite.size,
            .color = render.color,
            .mask = .{ .flipX = sprite.flip },
        });
    }
}

pub fn lessThan(lhs: Render, rhs: Render) bool {
    if (lhs.layer == rhs.layer) return lhs.depth < rhs.depth;
    return @intFromEnum(lhs.layer) < @intFromEnum(rhs.layer);
}

test "渲染排序先比较图层再比较深度" {
    const ground = Render{ .layer = .ground, .depth = 100 };
    const crop = Render{ .layer = .crop, .depth = 0 };
    const actorBack = Render{ .layer = .actor, .depth = 8 };
    const actorFront = Render{ .layer = .actor, .depth = 16 };

    try std.testing.expect(lessThan(ground, crop));
    try std.testing.expect(lessThan(actorBack, actorFront));
    try std.testing.expect(!lessThan(actorFront, actorBack));
}

fn setupCamera() void {
    zhu.camera.position = .zero;
    zhu.camera.size = .xy(320, 180);
    zhu.camera.scale = .one;
}

test "视口内精灵会被绘制" {
    setupCamera();
    var vertices: [4]zhu.batch.Vertex = undefined;
    var commands: [16]zhu.batch.Command = undefined;
    zhu.batch.vertexBuffer = .initBuffer(&vertices);
    zhu.batch.commandBuffer = .initBuffer(&commands);
    zhu.batch.commandBuffer.appendAssumeCapacity(.{});

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Position.xy(100, 50));
    world.add(entity, Sprite{
        .image = .{ .texture = .{ .id = 1 }, .size = .xy(16, 16) },
    });
    world.add(entity, Render{});

    draw(&world);

    try std.testing.expectEqual(1, zhu.batch.vertexBuffer.items.len);
}

test "视口外精灵不会被绘制" {
    setupCamera();
    var vertices: [4]zhu.batch.Vertex = undefined;
    var commands: [16]zhu.batch.Command = undefined;
    zhu.batch.vertexBuffer = .initBuffer(&vertices);
    zhu.batch.commandBuffer = .initBuffer(&commands);
    zhu.batch.commandBuffer.appendAssumeCapacity(.{});

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Position.xy(400, 50));
    world.add(entity, Sprite{
        .image = .{ .texture = .{ .id = 1 }, .size = .xy(16, 16) },
    });
    world.add(entity, Render{});

    draw(&world);

    try std.testing.expectEqual(@as(usize, 0), zhu.batch.vertexBuffer.items.len);
}

test "混合场景只绘制视口内精灵" {
    setupCamera();
    var vertices: [4]zhu.batch.Vertex = undefined;
    var commands: [16]zhu.batch.Command = undefined;
    zhu.batch.vertexBuffer = .initBuffer(&vertices);
    zhu.batch.commandBuffer = .initBuffer(&commands);
    zhu.batch.commandBuffer.appendAssumeCapacity(.{});

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const inside = world.createEntity();
    world.add(inside, Position.xy(50, 50));
    world.add(inside, Sprite{
        .image = .{ .texture = .{ .id = 1 }, .size = .xy(16, 16) },
    });
    world.add(inside, Render{});

    const outside = world.createEntity();
    world.add(outside, Position.xy(500, 500));
    world.add(outside, Sprite{
        .image = .{ .texture = .{ .id = 1 }, .size = .xy(16, 16) },
    });
    world.add(outside, Render{});

    draw(&world);

    try std.testing.expectEqual(1, zhu.batch.vertexBuffer.items.len);
}
