const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const window = zhu.window;
const camera = zhu.camera;

const map = @import("map.zig");

var texture: gfx.Texture = undefined;
var tilePosition: map.Vec = undefined;
var position: gfx.Vector = undefined;

pub fn init() void {
    tilePosition = map.playerStartPosition();
    computePosition();
    texture = map.getTextureFromTile(.player);
}

pub fn computePosition() void {
    position = map.playerWorldPosition(tilePosition);
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
    }
}

pub fn draw() void {
    camera.draw(texture, position);
}
