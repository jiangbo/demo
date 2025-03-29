const std = @import("std");
const gfx = @import("graphics.zig");

var allocator: std.mem.Allocator = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
    TextureCache.init();
    TextureSliceCache.init();
}

pub fn deinit() void {
    TextureSliceCache.deinit();
    TextureCache.deinit();
}

pub const TextureCache = struct {
    const Cache = std.StringHashMap(gfx.Texture);
    const stbImage = @import("c.zig").stbImage;

    var cache: Cache = undefined;

    pub fn init() void {
        cache = Cache.init(allocator);
    }

    pub fn load(path: [:0]const u8) ?gfx.Texture {
        const entry = cache.getOrPut(path) catch |e| {
            std.log.err("texture cache allocate error: {}", .{e});
            return null;
        };
        if (entry.found_existing) return entry.value_ptr.*;

        std.log.info("loading texture from: {s}", .{path});
        const image = stbImage.load(path) orelse return null;
        defer stbImage.unload(image);

        const texture = gfx.Texture.init(image.width, image.height, image.data);
        entry.value_ptr.* = texture;
        entry.key_ptr.* = allocator.dupe(u8, path) catch unreachable;
        return texture;
    }

    pub fn deinit() void {
        var keyIter = cache.keyIterator();
        while (keyIter.next()) |key| allocator.free(key.*);
        cache.deinit();
    }
};

pub const TextureSliceCache = struct {
    const Cache = std.StringHashMap([]gfx.Texture);

    var cache: Cache = undefined;

    pub fn init() void {
        cache = Cache.init(allocator);
    }

    pub fn load(comptime pathFmt: []const u8, from: u8, len: u8) ?[]const gfx.Texture {
        const entry = cache.getOrPut(pathFmt) catch |e| {
            std.log.err("texture slices cache allocate error: {}", .{e});
            return null;
        };
        if (entry.found_existing) return entry.value_ptr.*;

        const textures = allocator.alloc(gfx.Texture, len) catch |e| {
            std.log.err("texture slices allocate error: {}", .{e});
            return null;
        };

        gfx.loadTextures(textures, pathFmt, from);
        entry.value_ptr.* = textures;
        entry.key_ptr.* = allocator.dupe(u8, pathFmt) catch unreachable;
        return textures;
    }

    pub fn deinit() void {
        var iterator = cache.iterator();
        while (iterator.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        cache.deinit();
    }
};
