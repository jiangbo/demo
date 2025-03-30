const std = @import("std");
const gfx = @import("graphics.zig");

var allocator: std.mem.Allocator = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
}

pub fn deinit() void {
    TextureCache.deinit();
}

pub const TextureCache = struct {
    const stbImage = @import("c.zig").stbImage;
    const Cache = std.StringHashMapUnmanaged(gfx.Texture);

    var cache: Cache = undefined;

    pub fn load(path: [:0]const u8) gfx.Texture {
        const entry = cache.getOrPut(allocator, path) catch unreachable;
        if (entry.found_existing) return entry.value_ptr.*;

        std.log.info("loading texture from: {s}", .{path});
        const image = stbImage.load(path) catch unreachable;
        defer stbImage.unload(image);

        const texture = gfx.Texture.init(image.width, image.height, image.data);
        entry.value_ptr.* = texture;
        entry.key_ptr.* = allocator.dupe(u8, path) catch unreachable;
        return texture;
    }

    pub fn deinit() void {
        var keyIter = cache.keyIterator();
        while (keyIter.next()) |key| allocator.free(key.*);
        cache.deinit(allocator);
    }
};
