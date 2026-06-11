const std = @import("std");

pub const window = @import("window.zig");
pub const assets = @import("assets.zig");
pub const audio = @import("audio.zig");
pub const graphics = @import("graphics.zig");
pub const debug = @import("debug.zig");
pub const batch = @import("batch.zig");
pub const camera = @import("camera.zig");
pub const math = @import("math.zig");
pub const input = @import("input.zig");
pub const widget = @import("widget.zig");
pub const ecs = @import("ecs.zig");
pub const text = @import("text.zig");
pub const key = input.key;
pub const mouse = input.mouse;

pub const extend = struct {
    pub const tiled = @import("extend/tiled.zig");
};

pub const Timer = math.Timer;
pub const Image = graphics.Image;
pub const Atlas = graphics.Atlas;
pub const Vector2 = math.Vector2;
pub const Rect = math.Rect;
pub const Color = graphics.Color;
pub const Animation = graphics.Animation;
pub const EnumAnimation = graphics.EnumAnimation;
pub const isEnumRange = math.isEnumRange;

pub const Id = assets.Id;
pub fn id(comptime path: []const u8) assets.Id {
    return comptime assets.id(path);
}

pub fn getImage(comptime path: []const u8) ?graphics.Image {
    return assets.getImage(id(path));
}

pub fn nextEnum(E: type, value: anytype) E {
    const len = @typeInfo(E).@"enum".fields.len;
    if (@typeInfo(@TypeOf(value)) == .int) {
        return @enumFromInt((value + 1) % len);
    }
    return @enumFromInt((@intFromEnum(value) + 1) % len);
}

pub fn toEnum(E: type, value: anytype) E {
    const T = @TypeOf(value);
    if (T == []const u8) return std.meta.stringToEnum(E, value).?;
    if (@typeInfo(T) == .int) return @enumFromInt(value);
    @compileError("unsupported enum value type: " ++ T);
}

pub fn enumArray(E: type, V: type, values: []V) std.EnumArray(E, V) {
    var array: std.EnumArray(E, V) = .initUndefined();
    for (values, 0..) |value, i| array.set(@enumFromInt(i), value);
    return array;
}

fn EnumArrayByType(T: type) type {
    return std.EnumArray(@FieldType(T, "type"), @FieldType(T, "value"));
}
pub fn enumArrayByType(T: type, slice: anytype) EnumArrayByType(T) {
    var array: EnumArrayByType(T) = .initUndefined();
    for (slice) |value| array.set(value.type, value.value);
    return array;
}

pub const format = text.format;
pub const random = math.random;
pub const randomF32 = math.randomF32;
pub const randomInt = math.randomInt;
pub const randomIntMost = math.randomIntMost;
pub const randomEnum = math.randomEnum;
pub const randomBool = math.randomBool;
