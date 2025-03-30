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

    pub fn length(self: Vector3) f32 {
        return std.math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn normalize(self: Vector3) Vector3 {
        const len = self.length();
        return Vector3.init(self.x / len, self.y / len, self.z / len);
    }
};

pub const Rectangle = struct {
    left: f32 = 0,
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,

    pub fn init(x: f32, y: f32, w: f32, h: f32) Rectangle {
        return .{ .left = x, .top = y, .right = x + w, .bottom = y + h };
    }

    pub fn width(self: Rectangle) f32 {
        return self.right - self.left;
    }

    pub fn height(self: Rectangle) f32 {
        return self.bottom - self.top;
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
