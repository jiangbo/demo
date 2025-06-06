const std = @import("std");

const font = @import("bmfont.zig");
pub fn main() void {
    const data = @embedFile("4.fnt");
    const allocator = std.heap.c_allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    font.parse(arena.allocator(), data);

    // 写入 font.zon 文件
    const file = std.fs.cwd().createFile("font/font.zon", .{}) catch unreachable;
    defer file.close();
    const writer = file.writer();

    const result = Font{
        .lineHeight = font.bmfont.common.lineHeight,
        .chars = font.bmfont.chars,
    };

    std.zon.stringify.serialize(result, .{ .whitespace = false }, writer) catch unreachable;
}

const Font = struct {
    lineHeight: u16,
    chars: []const @import("font.zig").Char,
};
