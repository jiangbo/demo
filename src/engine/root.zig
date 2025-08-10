pub const window = @import("window.zig");
pub const audio = @import("audio.zig");
pub const gfx = @import("graphics.zig");
pub const camera = @import("camera.zig");
pub const math = @import("math.zig");
pub const input = @import("input.zig");

const std = @import("std");

pub fn format(buffer: []u8, comptime fmt: []const u8, args: anytype) []u8 {
    return std.fmt.bufPrint(buffer, fmt, args) catch unreachable;
}

pub const randU8 = math.randU8;
pub const randEnum = math.randEnum;
