const std = @import("std");

pub fn main() void {
    const font = @import("bmfont.zig");

    const data = @embedFile("6.fnt");
    const allocator = std.heap.c_allocator;
    const result = font.parse(allocator, data);

    // 写入 font.zon 文件
    const file = std.fs.cwd().createFile("src/font.zon", .{}) catch unreachable;
    defer file.close();
    const writer = file.writer();
    std.zon.stringify.serialize(result.chars, .{ .whitespace = false }, writer) catch unreachable;
}
