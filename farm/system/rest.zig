const zhu = @import("zhu");

const component = @import("../component.zig");
const ui = @import("../ui.zig");

const World = zhu.ecs.World;
const Interact = component.actor.Interact;
const Rest = component.map.Rest;

pub fn update(world: *World) void {
    const target = world.getIdentity(Interact) orelse return;
    if (!world.has(target, Rest)) return;

    ui.openRest();
}
