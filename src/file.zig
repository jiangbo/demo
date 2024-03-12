const std = @import("std");
const ray = @import("raylib.zig");

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

pub const Texture = struct {
    texture: ray.Texture2D,

    pub fn unload(self: Texture) void {
        ray.UnloadTexture(self.texture);
    }
};

pub fn loadTexture(name: []const u8) Texture {
    var buf: [maxPathLength]u8 = undefined;
    const path = std.fmt.bufPrintZ(&buf, "data/image/{s}", .{name}) catch |e| {
        std.log.err("load image error: {}", .{e});
        return Texture{ .texture = ray.Texture2D{} };
    };

    return Texture{ .texture = ray.LoadTexture(path) };
}
