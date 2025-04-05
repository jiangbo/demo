const std = @import("std");

pub const Vector = Vector3;
pub const Vector3 = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    pub fn init(x: f32, y: f32) Vector3 {
        return .{ .x = x, .y = y, .z = 0 };
    }

    pub fn add(self: Vector3, other: Vector3) Vector3 {
        return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }

    pub fn sub(self: Vector3, other: Vector3) Vector3 {
        return .{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
    }

    pub fn scale(self: Vector3, scalar: f32) Vector3 {
        return .{ .x = self.x * scalar, .y = self.y * scalar, .z = self.z * scalar };
    }

    pub fn length(self: Vector3) f32 {
        return std.math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn normalize(self: Vector3) Vector3 {
        const len = self.length();
        return Vector3.init(self.x / len, self.y / len, self.z / len);
    }
};

pub const Rectangle = struct {
    x: f32 = 0,
    y: f32 = 0,
    w: f32 = 0,
    h: f32 = 0,

    pub fn init(x1: f32, y1: f32, x2: f32, y2: f32) Rectangle {
        return .{ .x = x1, .y = y1, .w = x2 - x1, .h = y2 - y1 };
    }

    pub fn right(self: Rectangle) f32 {
        return self.x + self.w;
    }

    pub fn bottom(self: Rectangle) f32 {
        return self.y + self.h;
    }

    pub fn intersects(self: Rectangle, other: Rectangle) bool {
        return self.left < other.right and self.right > other.left and
            self.top < other.bottom and self.bottom > other.top;
    }

    pub fn contains(self: Rectangle, x: f32, y: f32) bool {
        return x >= self.left and x < self.right and
            y >= self.top and y < self.bottom;
    }
};
