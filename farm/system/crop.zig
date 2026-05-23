const std = @import("std");
const zhu = @import("zhu");

const factory = @import("../factory.zig");
const component = @import("../component.zig");
const Crop = component.farm.Crop;
const Sprite = component.render.Sprite;

pub fn update(world: *zhu.ecs.World, delta: f32) void {
    var query = world.query(.{ Crop, Sprite });
    while (query.next()) |entity| {
        const crop = query.getPtr(entity, Crop);
        if (crop.stage == .mature) continue;

        crop.timer += delta;
        if (crop.timer < crop.next) continue;

        const sprite = query.getPtr(entity, Sprite);
        sprite.* = factory.advanceCrop(crop);
    }
}
