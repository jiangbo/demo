const std = @import("std");

pub const Vector = Vector3;
pub const Vector3 = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    pub fn init2(x: f32, y: f32) Vector3 {
        return .{ .x = x, .y = y, .z = 0 };
    }

    pub fn init(x: f32, y: f32, z: f32) Vector3 {
        return .{ .x = x, .y = y, .z = z };
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
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,

    pub fn intersects(self: Rectangle, other: Rectangle) bool {
        return self.x < other.x + other.width and
            self.x + self.width > other.x and
            self.y < other.y + other.height and
            self.y + self.height > other.y;
    }

    pub fn contains(self: Rectangle, x: f32, y: f32) bool {
        return x >= self.x and x < self.x + self.width and
            y >= self.y and y < self.y + self.height;
    }
};
