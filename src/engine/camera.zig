const std = @import("std");

const math = @import("math.zig");
const window = @import("window.zig");

const Vector2 = math.Vector2;

pub var modeEnum: enum { world, window } = .world;
pub var position: Vector2 = .zero;
pub var worldSize: Vector2 = undefined;

pub fn toWorld(windowPosition: Vector2) Vector2 {
    return windowPosition.add(position);
}

pub fn toWindow(worldPosition: Vector2) Vector2 {
    return worldPosition.sub(position);
}

pub fn directFollow(pos: Vector2) void {
    // const scaleSize = window.logicSize.div(camera.scale);
    // const half = scaleSize.scale(0.5);
    const max = worldSize.sub(window.size).max(.zero);
    const halfWindowSize = window.size.scale(0.5);
    const square: Vector2 = .square(30);
    position = pos.sub(halfWindowSize);
    position.clamp(square.scale(-1), max.add(square));
}
