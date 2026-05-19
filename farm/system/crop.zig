const std = @import("std");
const zhu = @import("zhu");

const template = @import("../template.zig");
const component = @import("../component.zig");
const Crop = component.Crop;
const Sprite = component.Sprite;
const GrowthStage = component.GrowthStage;

fn spriteImage(comptime sprite: anytype) zhu.graphics.Image {
    const rect = sprite.rect;
    if (zhu.getImage(sprite.path)) |source| return source.sub(rect);
    return zhu.batch.whiteImage.sub(rect);
}

pub fn update(world: *zhu.ecs.World, delta: f32) void {
    var query = world.query(.{ Crop, Sprite });
    while (query.next()) |entity| {
        const crop = query.getPtr(entity, Crop);
        if (crop.stage == .mature) continue;

        const speed: f32 = if (crop.watered) 2.0 else 1.0;
        crop.timer += delta * speed;

        const durations = template.farm.crop.durations;
        if (crop.timer >= durations[@intFromEnum(crop.stage)]) {
            crop.timer = 0;
            crop.watered = false;
            crop.stage = zhu.nextEnum(GrowthStage, crop.stage);

            const sprite = query.getPtr(entity, Sprite);
            updateSprite(sprite, crop.stage);
        }
    }
}

fn updateSprite(sprite: *Sprite, stage: GrowthStage) void {
    switch (stage) {
        inline else => |s| {
            const config = @field(template.farm.crop.stages, @tagName(s));
            sprite.image = spriteImage(config);
            sprite.offset = config.offset;
        },
    }
}

test "种子阶段到期后会进入发芽阶段" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockCropImages();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Crop{ .timer = 4.9 });
    world.add(entity, Sprite{ .image = .{ .texture = .{ .id = 1 }, .size = .xy(16, 16) } });

    update(&world, 0.2);

    const crop = world.get(entity, Crop).?;
    try std.testing.expectEqual(GrowthStage.sprout, crop.stage);
    try std.testing.expectEqual(0, crop.timer);
}

test "浇水后生长速度翻倍" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockCropImages();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Crop{ .timer = 4.5, .watered = true });
    world.add(entity, Sprite{ .image = .{ .texture = .{ .id = 1 }, .size = .xy(16, 16) } });

    update(&world, 0.3);

    const crop = world.get(entity, Crop).?;
    try std.testing.expectEqual(GrowthStage.sprout, crop.stage);
    try std.testing.expectEqual(false, crop.watered);
}

test "成熟阶段不会继续生长" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Crop{ .stage = .mature });
    world.add(entity, Sprite{ .image = .{ .texture = .{ .id = 1 }, .size = .xy(16, 16) } });

    update(&world, 100);

    const crop = world.get(entity, Crop).?;
    try std.testing.expectEqual(GrowthStage.mature, crop.stage);
}

fn putMockCropImages() void {
    const image = zhu.graphics.Image{
        .texture = .{ .id = 1 },
        .size = .xy(256, 256),
    };
    inline for (@typeInfo(@TypeOf(template.farm.crop.stages)).@"struct".fields) |field| {
        const sprite = @field(template.farm.crop.stages, field.name);
        zhu.assets.putImage(zhu.assets.id(sprite.path), image);
    }
}
