const zhu = @import("zhu");

const component = @import("../component.zig");
const context = @import("../context.zig");
const farm = @import("farm.zig");

const Player = component.Player;
const Target = component.Target;

pub fn update(world: *zhu.ecs.World) void {
    if (context.uiWantCaptureMouse) return;
    if (!zhu.window.mouse.pressed(.LEFT)) return;

    const player = world.getIdentityEntity(Player).?;
    const target = world.get(player, Target).?;
    if (!target.active) return;

    farm.hoe(world, target.position);
}
