const std = @import("std");

pub const window = @import("window.zig");
pub const assets = @import("assets.zig");
pub const audio = @import("audio.zig");
pub const graphics = @import("graphics.zig");
pub const batch = @import("batch.zig");
pub const camera = @import("camera.zig");
pub const math = @import("math.zig");
pub const input = @import("input.zig");
pub const ecs = @import("ecs.zig");
pub const text = @import("text.zig");

pub const Atlas = graphics.Atlas;
pub const Vector2 = math.Vector2;
pub const Rect = math.Rect;
pub const Color = graphics.Color;

pub fn nextEnum(E: type, value: anytype) E {
    const len = @typeInfo(E).@"enum".fields.len;
    if (@typeInfo(@TypeOf(value)) == .int) {
        return @enumFromInt((value + 1) % len);
    }
    return @enumFromInt((@intFromEnum(value) + 1) % len);
}

pub fn sinInt(T: type, angle: f32, min: T, max: T) T {
    const minF: f32 = @floatFromInt(min);
    const maxF: f32 = @floatFromInt(max);
    const half = (maxF - minF) * 0.5;
    const result = minF + half + @sin(angle) * half;
    return @intFromFloat(@round(result));
}

pub const random = math.random;
pub const randomF32 = math.randomF32;
pub const randomInt = math.randomInt;
pub const randomIntMost = math.randomIntMost;
pub const randomEnum = math.randomEnum;
pub const randomBool = math.randomBool;
