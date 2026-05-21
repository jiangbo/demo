const std = @import("std");
const zhu = @import("zhu");

const spawn = @import("../spawn.zig");
const component = @import("../component.zig");
const Crop = component.Crop;
const Sprite = component.Sprite;

pub fn update(world: *zhu.ecs.World, delta: f32) void {
    var query = world.query(.{ Crop, Sprite });
    while (query.next()) |entity| {
        const crop = query.getPtr(entity, Crop);
        if (crop.stage == .mature) continue;

        crop.timer += delta;
        if (crop.timer < crop.next) continue;

        const sprite = query.getPtr(entity, Sprite);
        sprite.* = spawn.advanceCrop(crop);
    }
}
