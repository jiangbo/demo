const std = @import("std");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const c = @import("c.zig");
const sk = @import("sokol");

var allocator: std.mem.Allocator = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
    sk.fetch.setup(.{ .logger = .{ .func = sk.log.func } });
}

pub fn deinit() void {
    Texture.deinit();
    TextureSlice.deinit();
    RectangleSlice.deinit();
    // Sound.deinit();
    sk.fetch.shutdown();
}

pub fn loading() void {
    sk.fetch.dowork();
}

var loadingBuffer: [1024 * 1024]u8 = undefined;

pub fn send(path: [:0]const u8) void {
    std.log.info("loading {s}", .{path});

    _ = sk.fetch.send(.{
        .path = path,
        .callback = callback,
        .buffer = sk.fetch.asRange(&loadingBuffer),
    });
}

fn callback(responses: [*c]const sk.fetch.Response) callconv(.C) void {
    const response = responses[0];
    std.log.info("{}", .{response});

    if (response.failed) @panic("failed to load assets");

    const path = std.mem.span(response.path);
    if (std.mem.endsWith(u8, path, ".png")) {
        std.log.info("loaded texture from: {s}", .{path});

        const data = rangeToSlice(response.buffer);
        const image = c.stbImage.loadFromMemory(data) catch unreachable;
        defer c.stbImage.unload(image);

        Texture.init(path, image);
    }
}

fn rangeToSlice(range: sk.fetch.Range) []const u8 {
    return @as([*]const u8, @ptrCast(range.ptr))[0..range.size];
}

pub const Texture = struct {
    var cache: std.StringHashMapUnmanaged(gfx.Texture) = .empty;

    pub fn load(path: [:0]const u8) gfx.Texture {
        const entry = cache.getOrPut(allocator, path) catch unreachable;
        if (entry.found_existing) return entry.value_ptr.*;

        send(path);

        entry.value_ptr.* = .{ .value = sk.gfx.allocImage() };
        entry.key_ptr.* = allocator.dupe(u8, path) catch unreachable;
        return entry.value_ptr.*;
    }

    fn init(path: [:0]const u8, image: c.stbImage.Image) void {
        // defer c.stbImage.unload(image);
        cache.getPtr(path).?.init(image.width, image.height, image.data);
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
    var cache: std.StringHashMapUnmanaged([]gfx.Texture) = .empty;

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
    var cache: std.StringHashMapUnmanaged([]math.Rectangle) = .empty;

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

// const audio = @import("audio.zig");
// pub const Sound = struct {
//     var cache: std.StringHashMapUnmanaged(audio.Sound) = .empty;

//     pub fn load(path: [:0]const u8) audio.Sound {
//         const entry = cache.getOrPut(allocator, path) catch unreachable;
//         if (entry.found_existing) return entry.value_ptr.*;

//         std.log.info("loading audio from: {s}", .{path});
//         const stbAudio = c.stbAudio.load(path) catch unreachable;
//         defer c.stbAudio.unload(stbAudio);

//         var sound: audio.Sound = .{ .source = undefined };
//         const info = c.stbAudio.getInfo(stbAudio);
//         sound.channels = @intCast(info.channels);
//         sound.sampleRate = @intCast(info.sample_rate);

//         const size = c.stbAudio.getSampleCount(stbAudio) * sound.channels;
//         sound.source = allocator.alloc(f32, size) catch unreachable;

//         _ = c.stbAudio.fillSamples(stbAudio, sound.source, sound.channels);
//         entry.value_ptr.* = sound;
//         return sound;
//     }

//     pub fn deinit() void {
//         var iterator = cache.valueIterator();
//         while (iterator.next()) |value| allocator.free(value.source);
//         cache.deinit(allocator);
//     }
// };
