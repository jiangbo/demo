const std = @import("std");
const font = @import("font.zig");

pub fn parse(allocator: std.mem.Allocator, data: []const u8) font.Font {
    var arenaAllocator = std.heap.ArenaAllocator.init(allocator);
    var arena = arenaAllocator.allocator();
    var result: font.Font = undefined;

    var buffer = data;
    {
        // 验证文件头
        if (!std.mem.eql(u8, buffer[0..3], "BMF"))
            @panic("invalid file header");

        if (buffer[3] != 3) @panic("incompatible version");
        buffer = buffer[4..];
    }
    {
        // info block
        if (buffer[0] != 1) @panic("error info block tag");
        const len: usize = std.mem.readInt(u32, buffer[1..5], .little);
        buffer = buffer[5..];

        result.info = std.mem.bytesToValue(font.Info, buffer);
        std.log.info("info: {any}", .{result.info});

        const name = buffer[@sizeOf(font.Info) .. len - 1];
        result.name = arena.dupe(u8, name) catch unreachable;
        std.log.info("font name: {s}", .{result.name});
        buffer = buffer[len..];
    }
    {
        // common block
        if (buffer[0] != 2) @panic("error common block tag");
        const len: usize = std.mem.readInt(u32, buffer[1..5], .little);
        buffer = buffer[5..];

        result.common = std.mem.bytesToValue(font.Common, buffer);
        std.log.info("common: {any}", .{result.common});
        buffer = buffer[len..];
    }
    {
        // page block
        if (buffer[0] != 3) @panic("error page block tag");
        const len: usize = std.mem.readInt(u32, buffer[1..5], .little);
        buffer = buffer[5..];

        var pages = std.ArrayListUnmanaged([]const u8).empty;
        var readLength: usize = 0;
        while (readLength < len) {
            const name = std.mem.sliceTo(buffer, 0);
            std.log.info("file name: {s}", .{name});
            readLength += name.len + 1;
            pages.append(arena, name) catch unreachable;
        }
        result.pages = pages.toOwnedSlice(arena) catch unreachable;
        buffer = buffer[len..];
    }
    {
        // char block
        if (buffer[0] != 4) @panic("error char block tag");
        const len: usize = std.mem.readInt(u32, buffer[1..5], .little);
        buffer = buffer[5..];

        const charsCount: usize = @divExact(len, @sizeOf(font.Char));
        const chars = arena.alloc(font.Char, charsCount) catch unreachable;
        std.log.info("char number: {d}", .{charsCount});

        for (chars) |*char| {
            char.* = std.mem.bytesToValue(font.Char, buffer);
            buffer = buffer[@sizeOf(font.Char)..];
        }
        result.chars = chars;
    }
    {
        // kerning block
        if (buffer[0] != 5) @panic("error kerning block tag");
        const len: usize = std.mem.readInt(u32, buffer[1..5], .little);
        buffer = buffer[5..];

        const pairsCount: usize = @divExact(len, @sizeOf(font.KerningPair));
        const kerningPairs = arena.alloc(font.KerningPair, pairsCount) catch unreachable;
        std.log.info("kerning pair number: {d}", .{pairsCount});

        for (kerningPairs) |*pair| {
            pair.* = std.mem.bytesToValue(font.KerningPair, buffer);
            buffer = buffer[@sizeOf(font.KerningPair)..];
        }
        result.kerningPairs = kerningPairs;
    }

    if (buffer.len != 0) @panic("unexpected data at the end of file");
    return result;
}
