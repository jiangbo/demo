const std = @import("std");
const gfx = @import("graphics.zig");
const math = @import("math.zig");

var allocator: std.mem.Allocator = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
}

pub fn deinit() void {
    Texture.deinit();
    TextureSlice.deinit();
    RectangleSlice.deinit();
}

pub const Texture = struct {
    const stbImage = @import("c.zig").stbImage;

    var cache: std.StringHashMapUnmanaged(gfx.Texture) = undefined;

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

    pub fn loadSlice(textures: []gfx.Texture, comptime pathFmt: []const u8, from: u8) void {
        std.log.info("loading texture slice : {s}", .{pathFmt});

        var buffer: [128]u8 = undefined;
        for (from..from + textures.len) |index| {
            const path = std.fmt.bufPrintZ(&buffer, pathFmt, .{index});

            const texture = Texture.load(path catch unreachable);
            textures[index - from] = texture;
        }
    }

    pub fn deinit() void {
        var keyIter = cache.keyIterator();
        while (keyIter.next()) |key| allocator.free(key.*);
        cache.deinit(allocator);
    }
};

pub const TextureSlice = struct {
    var cache: std.StringHashMapUnmanaged([]gfx.Texture) = undefined;

    pub fn load(comptime pathFmt: []const u8, from: u8, len: u8) []const gfx.Texture {
        const entry = cache.getOrPut(allocator, pathFmt) catch unreachable;
        if (entry.found_existing) return entry.value_ptr.*;

        const textures = allocator.alloc(gfx.Texture, len) catch unreachable;

        Texture.loadSlice(textures, pathFmt, from);
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
        cache.deinit(allocator);
    }
};

pub const RectangleSlice = struct {
    var cache: std.StringHashMapUnmanaged([]math.Rectangle) = undefined;

    pub fn load(path: []const u8, count: u8) []math.Rectangle {
        const entry = cache.getOrPut(allocator, path) catch unreachable;
        if (entry.found_existing) return entry.value_ptr.*;

        const slice = allocator.alloc(math.Rectangle, count) catch unreachable;
        entry.value_ptr.* = slice;
        return slice;
    }

    pub fn deinit() void {
        var iterator = cache.valueIterator();
        while (iterator.next()) |value| allocator.free(value.*);
        cache.deinit(allocator);
    }
};
