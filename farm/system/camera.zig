const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const context = @import("../context.zig");

const Player = component.Player;
const Position = component.Position;

const followSmooth: f32 = 0.15;
const scaleStep: f32 = 0.1;

pub fn update(world: *zhu.ecs.World) void {
    updateScale();
    const player = world.getIdentityEntity(Player) orelse return;
    const position = world.get(player, Position) orelse return;
    zhu.camera.smoothFollow(position, followSmooth);
}

fn updateScale() void {
    if (context.uiWantCaptureMouse) return;

    const scroll = zhu.input.mouseScrollY;
    if (scroll == 0) return;

    const delta = if (scroll > 0) scaleStep else -scaleStep;
    const scale = std.math.clamp(zhu.camera.scale.x + delta, 0.5, 4);
    zhu.camera.scale = .xy(scale, scale);
}
