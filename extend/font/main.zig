const std = @import("std");

const font = @import("bmfont.zig");
pub fn main() !void {
    var debugAllocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debugAllocator.deinit();
    var arena = std.heap.ArenaAllocator.init(debugAllocator.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    if (args.len != 2) return error.invalidArgs;
    const name = args[1];
    std.log.info("file name: {s}", .{name});

    const max = std.math.maxInt(usize);
    const content = try std.fs.cwd().readFileAlloc(allocator, name, max);

    font.parse(allocator, content);

    // 写入 font.zon 文件
    const outputName = try std.mem.replaceOwned(u8, allocator, name, ".fnt", ".zon");
    const file = try std.fs.cwd().createFile(outputName, .{});
    defer file.close();
    var buffer: [4096]u8 = undefined;
    var writer = file.writer(&buffer);

    const size = font.bmfont.info.fontSize;
    const halfSize = @divExact(size, 2);
    const chars = try allocator.alloc(BitMapChar, font.bmfont.chars.len);
    for (chars, font.bmfont.chars) |*value, char| {
        value.id = char.id;
        value.area.min = .{ .x = char.x, .y = char.y };
        value.area.size = .{ .x = char.width, .y = char.height };
        value.offset = .{ .x = char.xOffset, .y = char.yOffset };
        const advance = if (char.id < 128) halfSize else size;
        if (char.xAdvance != advance) @panic("advance error");
    }

    const result = BitMapFont{
        .size = @floatFromInt(font.bmfont.info.fontSize),
        .lineHeight = font.bmfont.common.lineHeight,
        .chars = chars,
    };

    try std.zon.stringify.serialize(result, .{}, &writer.interface);
    try writer.interface.flush();
}

const BitMapFont = struct {
    size: f32,
    lineHeight: u16,
    chars: []const BitMapChar,
};

const Vec2 = struct { x: u16, y: u16 };
const Vec2i = struct { x: i16, y: i16 };
const BitMapChar = struct {
    id: u32,
    area: struct { min: Vec2, size: Vec2 },
    offset: Vec2i,
};
