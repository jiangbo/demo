const std = @import("std");

const math = @import("math.zig");
const key = @import("input.zig").key;

const Vector2 = math.Vector2;
const Matrix = math.Matrix;

pub const Camera = struct {
    position: Vector2,
    scale: Vector2,

    pub const default: Camera = .{ .position = .zero, .scale = .one };

    pub fn toWindow(self: Camera, point: Vector2) Vector2 {
        return point.sub(self.position).mul(self.scale);
    }

    pub fn toWorld(self: Camera, point: Vector2) Vector2 {
        return point.div(self.scale).add(self.position);
    }

    pub fn combine(self: Camera, child: Camera) Camera {
        return .{
            .position = self.position.add(child.position.div(self.scale)),
            .scale = self.scale.mul(child.scale),
        };
    }

    pub fn matrix(self: Camera) Matrix {
        const position = self.position.scale(-1).toVector3(0);
        const translate = Matrix.translateVec(position);
        const scaleMatrix = Matrix.scaleVec(self.scale.toVector3(1));
        return Matrix.mul(scaleMatrix, translate);
    }
};

var buffer: [8]Camera = undefined;
pub var stack: std.ArrayList(Camera) = .initBuffer(&buffer);
pub var size: Vector2 = undefined;
pub var bound: Vector2 = undefined;

pub fn init(cameraSize: Vector2) void {
    size, bound = .{ cameraSize, cameraSize };
    stack.clearRetainingCapacity();
    stack.appendAssumeCapacity(Camera.default);
}

pub fn push(position: Vector2, scale: Vector2) void {
    const camera = Camera{ .position = position, .scale = scale };
    stack.appendAssumeCapacity(camera);
}

pub fn pop() void {
    if (stack.items.len == 1) @panic("camera stack underflow");
    _ = stack.pop() orelse @panic("camera stack underflow");
}

pub fn top() *Camera {
    return &stack.items[stack.items.len - 1];
}

pub fn toWindow(point: Vector2) Vector2 {
    return top().toWindow(point);
}

pub fn toWorld(point: Vector2) Vector2 {
    return top().toWorld(point);
}

pub fn viewport() math.Rect {
    const camera = top();
    return .init(camera.position, size.div(camera.scale));
}

pub fn control(distance: f32) void {
    const camera = top();
    if (key.held(.UP)) camera.position.y -= distance;
    if (key.held(.DOWN)) camera.position.y += distance;
    if (key.held(.LEFT)) camera.position.x -= distance;
    if (key.held(.RIGHT)) camera.position.x += distance;
}

pub fn clampBound() void {
    const camera = top();
    const max = bound.sub(size.div(camera.scale)).max(.zero);
    camera.position.clamp(.zero, max);
}

pub fn directFollow(pos: Vector2) void {
    const camera = top();
    camera.position = pos.sub(size.div(camera.scale).scale(0.5));
    clampBound();
}

pub fn roundPosition() void {
    const camera = top();
    camera.position = camera.position.mul(camera.scale).round().div(camera.scale);
}

pub fn smoothFollow(pos: Vector2, smooth: f32) void {
    const camera = top();
    const target = pos.sub(size.div(camera.scale).scale(0.5));
    const distance = target.sub(camera.position);

    const clampedSmooth = std.math.clamp(smooth, 0, 1);
    if (@abs(distance.x) < 1) camera.position.x = target.x else {
        var moved = distance.x * clampedSmooth;
        if (@abs(moved) < 1) moved = math.ceilAway(moved);
        camera.position.x += moved;
    }

    if (@abs(distance.y) < 1) camera.position.y = target.y else {
        var moved = distance.y * clampedSmooth;
        if (@abs(moved) < 1) moved = math.ceilAway(moved);
        camera.position.y += moved;
    }
    clampBound();
}
