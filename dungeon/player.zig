const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const window = zhu.window;
const camera = zhu.camera;
const ecs = zhu.ecs;

const map = @import("map.zig");
const battle = @import("battle.zig");

pub var tilePosition: map.Vec = undefined;
var entity: ecs.Entity = undefined;

pub fn init() void {
    entity = ecs.w.createEntity();

    tilePosition = map.playerStartPosition();
    computePosition();

    ecs.w.add(entity, map.getTextureFromTile(.player));

    ecs.w.addContext(battle.TurnState.wait);
}

pub fn computePosition() void {
    const position = map.worldPosition(tilePosition);
    ecs.w.add(entity, position);

    const scaleSize = window.logicSize.div(camera.scale);
    const half = scaleSize.scale(0.5);
    const max = map.size.sub(scaleSize).max(.zero);
    camera.position = position.sub(half).clamp(.zero, max);
}

pub fn update(_: f32) void {
    var tilePos = tilePosition;
    if (window.isKeyRelease(.W)) tilePos.y -|= 1;
    if (window.isKeyRelease(.S)) tilePos.y += 1;
    if (window.isKeyRelease(.A)) tilePos.x -|= 1;
    if (window.isKeyRelease(.D)) tilePos.x += 1;

    const moved = tilePos.x != tilePosition.x or
        tilePos.y != tilePosition.y;

    if (moved and map.canEnter(tilePos)) {
        tilePosition = tilePos;
        computePosition();
        ecs.w.addContext(battle.TurnState.player);
    } else if (window.isKeyRelease(.SPACE)) {
        // 空格跳过当前回合
        ecs.w.addContext(battle.TurnState.player);
    }
}
