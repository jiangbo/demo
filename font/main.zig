const std = @import("std");

pub fn main() void {
    const font = @import("bmfont.zig");

    const data = @embedFile("6.fnt");
    const allocator = std.heap.c_allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    font.parse(arena.allocator(), data);

    // 写入 font.zon 文件
    const file = std.fs.cwd().createFile("font/font.zon", .{}) catch unreachable;
    defer file.close();
    const writer = file.writer();
    std.zon.stringify.serialize(font.bmfont.chars, .{ .whitespace = false }, writer) catch unreachable;
}
