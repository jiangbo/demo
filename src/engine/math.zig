const std = @import("std");

pub const FourDirection = enum { up, down, left, right };
// zig fmt: off
pub const EightDirection =enum { up, down, left, right,
                    leftUp, leftDown, rightUp, rightDown };
// zig fmt: on
pub const epsilon = 1e-4;

pub const Vector = Vector2;
pub const Vector2 = extern struct {
    x: f32 = 0,
    y: f32 = 0,

    pub const zero = Vector2{ .x = 0, .y = 0 };

    pub fn init(x: f32, y: f32) Vector2 {
        return .{ .x = x, .y = y };
    }

    pub fn toVector3(self: Vector2, z: f32) Vector3 {
        return .{ .x = self.x, .y = self.y, .z = z };
    }

    pub fn add(self: Vector2, other: Vector2) Vector2 {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub fn addX(self: Vector2, x: f32) Vector2 {
        return .{ .x = self.x + x, .y = self.y };
    }

    pub fn addY(self: Vector2, y: f32) Vector2 {
        return .{ .x = self.x, .y = self.y + y };
    }

    pub fn addXY(self: Vector2, x: f32, y: f32) Vector2 {
        return .{ .x = self.x + x, .y = self.y + y };
    }

    pub fn sub(self: Vector2, other: Vector2) Vector2 {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }

    pub fn mul(self: Vector2, other: Vector2) Vector2 {
        return .{ .x = self.x * other.x, .y = self.y * other.y };
    }

    pub fn div(self: Vector2, other: Vector2) Vector2 {
        return .{ .x = self.x / other.x, .y = self.y / other.y };
    }

    pub fn scale(self: Vector2, scalar: f32) Vector2 {
        return .{ .x = self.x * scalar, .y = self.y * scalar };
    }

    pub fn length(self: Vector2) f32 {
        return std.math.sqrt(self.x * self.x + self.y * self.y);
    }

    pub fn normalize(self: Vector2) Vector2 {
        return .{ .x = self.x / self.length(), .y = self.y / self.length() };
    }

    pub fn clamp(self: Vector2, min: Vector2, max: Vector2) Vector2 {
        return .{
            .x = std.math.clamp(self.x, min.x, max.x),
            .y = std.math.clamp(self.y, min.y, max.y),
        };
    }

    pub fn approxEqual(self: Vector2, other: Vector2) bool {
        return std.math.approxEqAbs(f32, self.x, other.x, epsilon) and
            std.math.approxEqAbs(f32, self.y, other.y, epsilon);
    }

    pub fn approxAbs(self: Vector2, other: Vector2, tolerance: f32) bool {
        return std.math.approxEqAbs(f32, self.x, other.x, tolerance) and
            std.math.approxEqAbs(f32, self.y, other.y, tolerance);
    }
};

pub const Vector4 = extern struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    w: f32 = 0,
    pub const zero = Vector4{ .x = 0, .y = 0, .z = 0, .w = 0 };
    pub const one = Vector4{ .x = 1, .y = 1, .z = 1, .w = 1 };
    pub const red = Vector4{ .x = 1, .w = 1 };
    pub const green = Vector4{ .y = 1, .w = 1 };
    pub const blue = Vector4{ .z = 1, .w = 1 };

    pub fn init(x: f32, y: f32, z: f32, w: f32) Vector4 {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }
};

pub const Vector3 = extern struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    pub const zero = Vector3{ .x = 0, .y = 0, .z = 0 };

    pub fn init(x: f32, y: f32) Vector3 {
        return .{ .x = x, .y = y, .z = 1 };
    }
};

pub const Rectangle = struct {
    min: Vector2 = .zero,
    max: Vector2 = .zero,

    pub fn init(position: Vector2, sizeV: Vector2) Rectangle {
        return Rectangle{ .min = position, .max = position.add(sizeV) };
    }

    pub fn size(self: Rectangle) Vector2 {
        return self.max.sub(self.min);
    }

    pub fn center(self: Rectangle) Vector2 {
        return self.min.add(self.size().scale(0.5));
    }

    pub fn move(self: Rectangle, offset: Vector2) Rectangle {
        return .{ .min = self.min.add(offset), .max = self.max.add(offset) };
    }

    pub fn intersect(self: Rectangle, other: Rectangle) bool {
        return self.min.x < other.max.x and self.max.x > other.min.x and
            self.min.y < other.max.y and self.max.y > other.min.y;
    }

    pub fn contains(self: Rectangle, point: Vector2) bool {
        return point.x >= self.min.x and point.x <= self.max.x and
            point.y >= self.min.y and point.y <= self.max.y;
    }

    pub fn toVector4(self: Rectangle) Vector4 {
        return .{
            .x = self.min.x,
            .y = self.min.y,
            .z = self.max.x,
            .w = self.max.y,
        };
    }
};

pub var rand: std.Random.DefaultPrng = undefined;

pub fn setRandomSeed(seed: u64) void {
    rand = .init(seed);
}

pub fn random() std.Random {
    return rand.random();
}

pub fn randF32(min: f32, max: f32) f32 {
    return random().float(f32) * (max - min) + min;
}

pub fn randU8(min: u8, max: u8) u8 {
    return random().intRangeAtMostBiased(u8, min, max);
}
