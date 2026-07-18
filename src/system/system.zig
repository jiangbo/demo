const ecs = @import("ecs");

pub const animation = @import("animation.zig");
pub const control = @import("control.zig");
pub const movement = @import("movement.zig");
pub const render = @import("render.zig");
pub const talk = @import("talk.zig");
pub const wander = @import("wander.zig");

pub fn update(world: *ecs.World, delta: f32) void {
    wander.update(world, delta);
    control.update(world);
    movement.update(world, delta);
    talk.update(world);
    animation.update(world, delta);
}
