const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const window = zhu.window;
const camera = zhu.camera;
const ecs = zhu.ecs;

const map = @import("map.zig");
const battle = @import("battle.zig");

pub var entity: ecs.Entity = undefined;

pub fn init() void {
    entity = ecs.w.createEntity();
    const tilePos = map.center(map.rooms[0]);
    ecs.w.add(entity, tilePos);
    ecs.w.add(entity, map.getTextureFromTile(.player));
    ecs.w.add(entity, map.worldPosition(tilePos));
    const health: battle.Health = .{ .max = 20, .current = 20 };
    ecs.w.add(entity, health);
    ecs.w.addContext(battle.TurnState.wait);
}

pub fn update(_: f32) void {
    const tilePosition = ecs.w.get(entity, map.Vec).?;
    var tilePos = tilePosition;
    if (window.isKeyRelease(.W)) tilePos.y -|= 1 //
    else if (window.isKeyRelease(.S)) tilePos.y += 1 //
    else if (window.isKeyRelease(.A)) tilePos.x -|= 1 //
    else if (window.isKeyRelease(.D)) tilePos.x += 1; //

    _ = ecs.w.removeIdentity(map.WantsToMove);
    if (!tilePosition.equals(tilePos)) {
        ecs.w.add(entity, map.WantsToMove{tilePos});
        ecs.w.addIdentity(entity, map.WantsToMove);
        ecs.w.addContext(battle.TurnState.player);
    } else if (window.isKeyRelease(.SPACE)) {
        // 空格跳过当前回合
        ecs.w.addContext(battle.TurnState.player);
    }
}
