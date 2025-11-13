const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const window = zhu.window;
const camera = zhu.camera;
const ecs = zhu.ecs;

const map = @import("map.zig");
const component = @import("component.zig");

const Player = component.Player;
const Health = component.Health;
const TurnState = component.TurnState;
const TilePosition = component.TilePosition;
const WantToMove = component.WantToMove;
const Amulet = component.Amulet;

pub fn init() void {
    const entity = ecs.w.createIdentityEntity(Player);

    const tilePosition = map.rooms[0].center();
    ecs.w.add(entity, tilePosition);
    ecs.w.add(entity, WantToMove{tilePosition});
    ecs.w.add(entity, map.getTextureFromTile(.player));
    ecs.w.add(entity, map.worldPosition(tilePosition));
    const health: Health = .{ .max = 10, .current = 10 };
    ecs.w.add(entity, health);
    ecs.w.addContext(TurnState.wait);
}

pub fn move() void {
    const entity = ecs.w.getIdentityEntity(Player).?;

    const tilePosition = ecs.w.get(entity, TilePosition).?;
    var tilePos = tilePosition;
    if (window.isKeyRelease(.W)) tilePos.y -|= 1 //
    else if (window.isKeyRelease(.S)) tilePos.y += 1 //
    else if (window.isKeyRelease(.A)) tilePos.x -|= 1 //
    else if (window.isKeyRelease(.D)) tilePos.x += 1; //

    _ = ecs.w.remove(entity, WantToMove);
    if (!tilePosition.equals(tilePos)) {
        const amuletPos = ecs.w.getIdentity(Amulet, TilePosition).?;
        if (amuletPos.equals(tilePos)) {
            ecs.w.addContext(TurnState.win);
        } else {
            ecs.w.add(entity, WantToMove{tilePos});
            ecs.w.addContext(TurnState.player);
        }
    } else if (window.isKeyRelease(.SPACE)) {
        // 空格跳过当前回合
        ecs.w.addContext(TurnState.player);
        var health = ecs.w.getPtr(entity, Health).?;
        health.current = @min(health.max, health.current + 1);
    }
}
