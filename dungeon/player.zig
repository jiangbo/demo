const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const window = zhu.window;
const camera = zhu.camera;
const ecs = zhu.ecs;

const map = @import("map.zig");
const components = @import("components.zig");

const Player = components.Player;
const Health = components.Health;
const TurnState = components.TurnState;
const TilePosition = components.TilePosition;
const WantToMove = components.WantToMove;

pub fn init() void {
    const entity = ecs.w.createEntity();
    ecs.w.addIdentity(entity, Player);

    const tilePosition = map.rooms[0].center();
    ecs.w.add(entity, tilePosition);
    ecs.w.add(entity, WantToMove{tilePosition});
    ecs.w.add(entity, map.getTextureFromTile(.player));
    ecs.w.add(entity, map.worldPosition(tilePosition));
    const health: Health = .{ .max = 20, .current = 20 };
    ecs.w.add(entity, health);
    ecs.w.addContext(TurnState.wait);
}

pub fn move() void {
    const entity = ecs.w.getIdentityEntity(components.Player).?;

    const tilePosition = ecs.w.get(entity, TilePosition).?;
    var tilePos = tilePosition;
    if (window.isKeyRelease(.W)) tilePos.y -|= 1 //
    else if (window.isKeyRelease(.S)) tilePos.y += 1 //
    else if (window.isKeyRelease(.A)) tilePos.x -|= 1 //
    else if (window.isKeyRelease(.D)) tilePos.x += 1; //

    _ = ecs.w.removeIdentity(WantToMove);
    if (!tilePosition.equals(tilePos)) {
        ecs.w.add(entity, WantToMove{tilePos});
        ecs.w.addContext(TurnState.player);
    } else if (window.isKeyRelease(.SPACE)) {
        // 空格跳过当前回合
        ecs.w.addContext(TurnState.player);
        var health = ecs.w.getPtr(entity, Health).?;
        health.current = @min(health.max, health.current + 1);
    }
}
