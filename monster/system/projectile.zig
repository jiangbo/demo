const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");
const spawn = @import("../spawn.zig");

pub fn update(reg: *zhu.ecs.Registry, delta: f32) void {
    spawn.projectile(reg, delta);

    // 更新所有投射物的飞行状态
    var view = reg.reverseView(.{com.Projectile});
    while (view.next()) |entity| {
        const projectile = view.getPtr(entity, com.Projectile);
        projectile.time += delta;

        // 飞行时间是否大于等于总时间
        if (projectile.time >= projectile.totalTime) {
            reg.add(projectile.owner, com.attack.Hit{});
            view.destroy(entity);
            continue;
        }

        // 计算移动的位置
        var percent = projectile.time / projectile.totalTime;
        percent = std.math.clamp(percent, 0.0, 1.0);
        var pos = projectile.start.mix(projectile.end, percent);

        const arc = @sin(percent * std.math.pi) * projectile.arc;
        pos = pos.addY(-arc).add(projectile.offset);
        view.add(entity, pos);

        // 处理旋转角度
        const direction = pos.sub(projectile.previous);
        projectile.rotation = std.math.atan2(direction.y, direction.x);
        projectile.previous = pos;
    }
}

pub fn draw(reg: *zhu.ecs.Registry) void {
    var view = reg.view(.{com.Projectile});

    while (view.next()) |entity| {
        const projectile = view.getPtr(entity, com.Projectile);
        const image = view.get(entity, zhu.graphics.Image);
        const position = view.get(entity, com.Position);
        zhu.batch.drawImage(image, position, .{
            .radian = projectile.rotation,
        });
    }
}
