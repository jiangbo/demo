const std = @import("std");
const win32 = @import("win32");
const d3d = @import("d3d.zig");

const d3d9 = win32.graphics.direct3d9;

pub const UNICODE: bool = true;

pub fn main() !void {
    std.log.debug("hello world", .{});

    d3d.initDirectX(640, 480);
}
