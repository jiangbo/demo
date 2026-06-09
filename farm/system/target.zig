const zhu = @import("zhu");

const component = @import("../component.zig");
const context = @import("../context.zig");
const map = @import("../map.zig");

const Player = component.actor.Player;
const Position = component.Position;
const Target = component.ui.Target;

const tileRange: i32 = 1;

pub fn update(world: *zhu.ecs.World) void {
    const player = world.getIdentity(Player).?;
    const target = world.getPtr(player, Target).?;

    if (context.ui.mouseCaptured() or context.input.mouseCaptured) {
        target.active = false;
        return;
    }

    const playerPos = world.get(player, Position).?;

    const playerTile = map.data.worldToTilePosition(playerPos);
    const mouseWorld = zhu.camera.toWorld(zhu.window.mouse);
    const mouseTile = map.data.worldToTilePosition(mouseWorld);

    const outOfRangeX = @abs(mouseTile.x - playerTile.x) > tileRange;
    if (outOfRangeX or @abs(mouseTile.y - playerTile.y) > tileRange) {
        target.active = false;
        return;
    }

    target.position = map.data.tilePositionToWorld(mouseTile);
    target.active = true;
}

pub fn draw(world: *zhu.ecs.World) void {
    const player = world.getIdentity(Player).?;
    const target = world.get(player, Target).?;
    if (!target.active) return;

    const rect = zhu.Rect.init(target.position, map.data.tileSize);
    zhu.batch.drawRect(rect, .{ .color = target.color });
}
