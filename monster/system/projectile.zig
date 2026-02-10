const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");
const spawn = @import("../spawn.zig");

pub fn update(reg: *zhu.ecs.Registry, delta: f32) void {
    spawn.spawnProjectile(reg);
    _ = delta;
}

pub fn draw(reg: *zhu.ecs.Registry) void {
    var view = reg.view(.{com.Projectile});

    while (view.next()) |entity| {
        const image = view.get(entity, zhu.graphics.Image);
        const position = view.get(entity, com.Position);
        zhu.batch.drawImage(image, position, .{});
    }
}
