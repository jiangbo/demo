const ecs = @import("ecs");

pub const animation = @import("animation.zig");
pub const render = @import("render.zig");

pub fn update(world: *ecs.World, delta: f32) void {
    animation.update(world, delta);
}
