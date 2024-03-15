const std = @import("std");
const image = @import("engine/image.zig");

pub usingnamespace @import("engine/engine.zig");
pub const Rectangle = @import("engine/basic.zig").Rectangle;
pub const Image = image.Image;
pub const TileMap = image.TileMap;
pub const Key = @import("engine/key.zig").Key;

const maxPathLength = 30;

pub fn readStageText(allocator: std.mem.Allocator, level: usize) ![]const u8 {
    var buf: [maxPathLength]u8 = undefined;
    const path = try std.fmt.bufPrint(&buf, "data/stage/{}.txt", .{level});

    std.log.info("load stage: {s}", .{path});
    return try readAll(allocator, path);
}

fn readAll(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(name, .{});
    defer file.close();

    return try file.readToEndAlloc(allocator, std.math.maxInt(usize));
}
