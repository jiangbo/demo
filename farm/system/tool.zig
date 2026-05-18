const zhu = @import("zhu");

const component = @import("../component.zig");
const context = @import("../context.zig");
const map = @import("../map.zig");

const Player = component.Player;
const Target = component.Target;

const Tool = enum {
    hoe,
    water,
};

var current: Tool = .hoe;

pub fn update(world: *zhu.ecs.World) void {
    updateSelection();

    if (context.uiWantCaptureMouse) return;
    if (!zhu.window.mouse.pressed(.LEFT)) return;

    const player = world.getIdentityEntity(Player).?;
    const target = world.get(player, Target).?;
    if (!target.active) return;

    switch (current) {
        .hoe => map.hoe(target.position),
        .water => map.water(target.position),
    }
}

fn updateSelection() void {
    if (context.uiWantCaptureKeyboard) return;

    if (zhu.input.key.pressed(._1)) current = .hoe;
    if (zhu.input.key.pressed(._2)) current = .water;
}
