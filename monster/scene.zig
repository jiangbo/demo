const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;

const map = @import("map.zig");
const com = @import("component.zig");

pub fn init() void {
    ecs.init(zhu.assets.allocator);

    map.init();
    var image = zhu.assets.loadImage("assets/textures/Enemy/wolf.png", .xy(5760, 768));
    image = image.sub(.init(.zero, .xy(192, 192)));

    const wolf = ecs.reg.createEntity();
    ecs.reg.add(wolf, com.Sprite{
        .image = image,
        .offset = .xy(-96, -128),
        .flip = true,
    });
    ecs.reg.add(wolf, com.Position{ .x = 400, .y = 300 });
    ecs.reg.add(wolf, com.Velocity{ .v = .xy(20, 0) });
}

pub fn deinit() void {
    map.deinit();
    ecs.deinit();
}

pub fn update(delta: f32) void {
    map.update(delta);

    var view = ecs.reg.view(.{ com.Position, com.Velocity });
    while (view.next()) |entity| {
        const position = view.getPtr(entity, com.Position);
        const velocity = view.get(entity, com.Velocity);
        position.* = position.*.add(velocity.v.scale(delta));
    }
}

pub fn draw() void {
    map.draw();

    var view = ecs.reg.view(.{ com.Sprite, com.Position });
    while (view.next()) |entity| {
        const sprite = view.get(entity, com.Sprite);
        const position = view.get(entity, com.Position);
        const pos = position.add(sprite.offset);
        zhu.batch.drawImage(sprite.image, pos, .{
            .flipX = sprite.flip,
        });
        const rect: zhu.Rect = .init(pos, sprite.image.rect.size);
        zhu.batch.drawRectBorder(rect, 2, .green);
    }

    for (map.startPaths) |start| {
        if (start == 0) break;

        var prev = map.paths.get(start).?;
        while (prev.next != 0) {
            const next = map.paths.get(prev.next).?;
            zhu.batch.drawLine(prev.point, next.point, .{
                .color = .red,
                .width = 4,
            });
            prev = next;
        }
    }
}
