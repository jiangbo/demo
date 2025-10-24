const std = @import("std");

pub const FourDirection = enum {
    up,
    down,
    left,
    right,

    pub fn random() FourDirection {
        return randEnum(FourDirection);
    }

    pub fn opposite(self: FourDirection) FourDirection {
        return switch (self) {
            .up => .down,
            .down => .up,
            .left => .right,
            .right => .left,
        };
    }
};
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
    pub const one = Vector2{ .x = 1, .y = 1 };

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

    pub fn round(self: Vector2) Vector2 {
        return .{ .x = @round(self.x), .y = @round(self.y) };
    }

    pub fn floor(self: Vector2) Vector2 {
        return .{ .x = @floor(self.x), .y = @floor(self.y) };
    }

    pub fn clamp(self: Vector2, minV: Vector2, maxV: Vector2) Vector2 {
        return .{
            .x = std.math.clamp(self.x, minV.x, maxV.x),
            .y = std.math.clamp(self.y, minV.y, maxV.y),
        };
    }

    pub fn max(self: Vector2, other: Vector2) Vector2 {
        return .{
            .x = @max(self.x, other.x),
            .y = @max(self.y, other.y),
        };
    }

    pub fn min(self: Vector2, other: Vector2) Vector2 {
        return .{
            .x = @min(self.x, other.x),
            .y = @min(self.y, other.y),
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
    pub const black = Vector4{ .x = 0, .y = 0, .z = 0, .w = 1 };
    pub const white = one;
    pub const red = Vector4{ .x = 1, .w = 1 };
    pub const green = Vector4{ .y = 1, .w = 1 };
    pub const blue = Vector4{ .z = 1, .w = 1 };
    pub const yellow = Vector4{ .x = 1, .y = 1, .w = 1 };

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

pub const Rect = struct {
    min: Vector2 = .zero,
    size: Vector2 = .one,

    pub fn init(position: Vector2, sizeV: Vector2) Rect {
        return Rect{ .min = position, .size = sizeV };
    }

    pub fn fromMax(minV: Vector2, maxV: Vector2) Rect {
        return Rect{ .min = minV, .size = maxV.sub(minV) };
    }

    pub fn max(self: Rect) Vector2 {
        return self.min.add(self.size);
    }

    pub fn move(self: Rect, offset: Vector2) Rect {
        return .{ .min = self.min.add(offset), .size = self.size };
    }

    pub fn center(self: Rect) Vector2 {
        return self.min.add(self.size.scale(0.5));
    }

    pub fn contains(self: Rect, point: Vector2) bool {
        return point.x >= self.min.x and point.x <= self.max().x and
            point.y >= self.min.y and point.y <= self.max().y;
    }

    pub fn intersect(self: Rect, other: Rect) bool {
        return self.min.x < other.max().x and self.max().x > other.min.x and
            self.min.y < other.max().y and self.max().y > other.min.y;
    }

    pub fn toVector4(self: Rect) Vector4 {
        return .init(self.min.x, self.min.y, self.max().x, self.max().y);
    }
};

// pub const Rectangle1 = struct {
//     min: Vector2 = .zero,
//     max: Vector2 = .zero,

//     pub fn init(position: Vector2, sizeV: Vector2) Rectangle {
//         return Rectangle{ .min = position, .max = position.add(sizeV) };
//     }

//     pub fn size(self: Rectangle) Vector2 {
//         return self.max.sub(self.min);
//     }

//     pub fn center(self: Rectangle) Vector2 {
//         return self.min.add(self.size().scale(0.5));
//     }

//     pub fn move(self: Rectangle, offset: Vector2) Rectangle {
//         return .{ .min = self.min.add(offset), .max = self.max.add(offset) };
//     }

//     pub fn intersect(self: Rectangle, other: Rectangle) bool {
//         return self.min.x < other.max.x and self.max.x > other.min.x and
//             self.min.y < other.max.y and self.max.y > other.min.y;
//     }

//     pub fn contains(self: Rectangle, point: Vector2) bool {
//         return point.x >= self.min.x and point.x <= self.max.x and
//             point.y >= self.min.y and point.y <= self.max.y;
//     }

//     pub fn sub(self: Rectangle, area: Rectangle) Rectangle {
//         return .init(self.min.add(area.min), area.size());
//     }

//     pub fn toVector4(self: Rectangle) Vector4 {
//         return .{
//             .x = self.min.x,
//             .y = self.min.y,
//             .z = self.max.x,
//             .w = self.max.y,
//         };
//     }
// };

pub const Matrix = struct {
    mat: [16]f32,

    pub const identity = Matrix{ .mat = [16]f32{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    } };

    pub fn orthographic(width: f32, height: f32, near: f32, far: f32) Matrix {
        return .{ .mat = [16]f32{
            2.0 / width, 0,             0,                   0,
            0,           -2.0 / height, 0,                   0,
            0,           0,             1.0 / (far - near),  0,
            -1.0,        1.0,           near / (near - far), 1,
        } };
    }

    pub fn mul(m1: Matrix, m2: Matrix) Matrix {
        var result: [16]f32 = undefined;
        for (0..4) |i| {
            for (0..4) |j| {
                var sum: f32 = 0;
                for (0..4) |k| {
                    sum += m1.mat[i + k * 4] * m2.mat[k + j * 4];
                }
                result[i + j * 4] = sum;
            }
        }
        return .{ .mat = result };
    }

    pub fn translate(x: f32, y: f32, z: f32) Matrix {
        return .{ .mat = [16]f32{
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            x, y, z, 1,
        } };
    }

    pub fn translateVec(vec: Vector3) Matrix {
        return translate(vec.x, vec.y, vec.z);
    }

    pub fn scale(x: f32, y: f32, z: f32) Matrix {
        return .{ .mat = [16]f32{
            x, 0, 0, 0,
            0, y, 0, 0,
            0, 0, z, 0,
            0, 0, 0, 1,
        } };
    }

    pub fn scaleVec(vec: Vector3) Matrix {
        return scale(vec.x, vec.y, vec.z);
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

pub fn randomInt(T: type, min: T, max: T) T {
    return random().intRangeLessThanBiased(T, min, max);
}

pub fn randomIntMost(T: type, min: T, max: T) T {
    return random().intRangeAtMostBiased(T, min, max);
}

pub fn randEnum(comptime EnumType: type) EnumType {
    return random().enumValue(EnumType);
}
