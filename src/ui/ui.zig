const ecs = @import("ecs");

const component = @import("../component.zig");
const zon = @import("../zon.zig");
const dialog = @import("dialog.zig");
const tip = @import("tip.zig");

const Dialog = component.dialog.Dialog;

pub fn init() void {
    dialog.init();
}

pub fn reset() void {
    tip.reset();
}

pub fn update(world: *ecs.World, delta: f32) ?zon.dialog.Event {
    tip.update(world, delta);
    if (world.has(world.entity, Dialog)) tip.reset();
    return dialog.update(world);
}

pub fn draw(world: *ecs.World) void {
    dialog.draw(world);
    if (!world.has(world.entity, Dialog)) tip.draw();
}
