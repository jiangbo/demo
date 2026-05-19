const std = @import("std");

const math = @import("math.zig");
const window = @import("window.zig");

const Vector2 = math.Vector2;

pub var mode: enum { world, window, fixed } = .world;
pub var position: Vector2 = .zero;
pub var scale: Vector2 = .one;
pub var size: Vector2 = undefined;
pub var bound: Vector2 = undefined;

pub fn init() void {
    size, bound = .{ window.size, window.size };
}

pub fn toWorld(windowPosition: Vector2) Vector2 {
    return windowPosition.div(scale).add(position);
}

pub fn toWindow(worldPosition: Vector2) Vector2 {
    return worldPosition.sub(position).mul(scale);
}

pub fn control(distance: f32) void {
    if (window.isKeyDown(.UP)) position.y -= distance;
    if (window.isKeyDown(.DOWN)) position.y += distance;
    if (window.isKeyDown(.LEFT)) position.x -= distance;
    if (window.isKeyDown(.RIGHT)) position.x += distance;
}

pub fn clampBound() void {
    const max = bound.sub(size.div(scale)).max(.zero);
    position.clamp(.zero, max);
}

pub fn directFollow(pos: Vector2) void {
    position = pos.sub(size.div(scale).scale(0.5));
    clampBound();
}

pub fn smoothFollow(pos: Vector2, smooth: f32) void {
    const target = pos.sub(size.div(scale).scale(0.5));
    const distance = target.sub(position);

    const clampedSmooth = std.math.clamp(smooth, 0, 1);
    if (@abs(distance.x) < 1) position.x = target.x else {
        var moved = distance.x * clampedSmooth;
        if (@abs(moved) < 1) moved = math.ceilAway(moved);
        position.x += moved;
    }

    if (@abs(distance.y) < 1) position.y = target.y else {
        var moved = distance.y * clampedSmooth;
        if (@abs(moved) < 1) moved = math.ceilAway(moved);
        position.y += moved;
    }
    clampBound();
}
