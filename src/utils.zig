const Entity = @import("obj.zig").Entity;

pub fn collision(e1: *Entity, e2: *Entity) bool {
    if ((e1.x + e1.w) < e2.x or e2.x + e2.w < e1.x) return false;
    if ((e1.y + e1.h) < e2.y or e2.y + e2.h < e1.y) return false;
    return true;
}

pub fn calcSlope(e1: *Entity, e2: *Entity, e3: *Entity) void {
    const e1x = e1.x + e1.w / 2;
    const e1y = e1.y + e1.h / 2;
    const steps = @max(@abs(e1x - e2.x), @abs(e1y - e2.y));

    if (steps == 0) {
        e3.dx = 0;
        e3.dy = 0;
        return;
    }

    e3.dx = (e1x - e2.x) / steps;
    e3.dy = (e1y - e2.y) / steps;
}
