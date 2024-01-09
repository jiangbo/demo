const Entity = @import("obj.zig").Entity;

pub fn collision(e1: *Entity, e2: *Entity) bool {
    const e1w: f32 = @floatFromInt(e1.w);
    const e2w: f32 = @floatFromInt(e2.w);
    if ((e1.x + e1w) < e2.x or e2.x + e2w < e1.x) return false;

    const e1h: f32 = @floatFromInt(e1.h);
    const e2h: f32 = @floatFromInt(e2.h);
    if ((e1.y + e1h) < e2.y or e2.y + e2h < e1.y) return false;

    return true;
}
