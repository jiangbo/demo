const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");

const Player = component.actor.Player;
const Position = component.Position;

const followSmooth: f32 = 0.15;
const scaleStep: f32 = 0.1;

pub fn update(world: *zhu.ecs.World) void {
    const player = world.getIdentity(Player).?;
    const position = world.get(player, Position).?;
    updateScale(position);
    zhu.camera.smoothFollow(position, followSmooth);
    zhu.camera.roundPosition();
}

fn updateScale(position: Position) void {
    const scroll = zhu.input.mouseScrollY;
    if (scroll == 0) return;

    const delta = if (scroll > 0) scaleStep else -scaleStep;
    const scale = std.math.clamp(zhu.camera.scale.x + delta, 0.5, 4);
    zhu.camera.scale = .xy(scale, scale);
    zhu.camera.directFollow(position); // 直接跟踪
}

test "相机跟随会向玩家位置移动" {
    zhu.camera.position = .zero;
    zhu.camera.size = .xy(640, 360);
    zhu.camera.scale = .one;
    zhu.camera.bound = .xy(1280, 720);

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.add(player, Position.xy(700, 400));

    update(&world);

    try std.testing.expect(zhu.camera.position.x > 0);
    try std.testing.expect(zhu.camera.position.y > 0);
}
