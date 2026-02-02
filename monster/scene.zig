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
    ecs.reg.add(wolf, image);
    ecs.reg.add(wolf, com.Position{ .x = 400, .y = 300 });

    // registry_.emplace<engine::component::SpriteComponent>(enemy, std::move(sprite), glm::vec2(192, 192), glm::vec2(-96, -128));
}

pub fn deinit() void {
    map.deinit();
    ecs.deinit();
}

pub fn update(delta: f32) void {
    map.update(delta);
}

pub fn draw() void {
    map.draw();

    var view = ecs.reg.view(.{ com.Image, com.Position });
    while (view.next()) |entity| {
        const image = view.get(entity, com.Image);
        const position = view.get(entity, com.Position);
        zhu.batch.drawImage(image, position, .{});

        const rect: zhu.Rect = .init(position, image.rect.size);
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
