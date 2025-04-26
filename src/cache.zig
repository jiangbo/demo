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
    Sound.deinit();
    sk.fetch.shutdown();
}

pub fn loading() void {
    sk.fetch.dowork();
}

var loadingBuffer: [1.5 * 1024 * 1024]u8 = undefined;

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

    if (response.failed) {
        std.log.info("failed to load assets, path: {s}", .{response.path});
        return;
    }

    const path = std.mem.span(response.path);
    if (std.mem.endsWith(u8, path, ".png")) {
        std.log.info("loaded texture from: {s}", .{path});
        Texture.init(path, rangeToSlice(response.buffer));
    } else if (std.mem.endsWith(u8, path, "bgm.ogg")) {
        std.log.info("loaded bgm from: {s}", .{path});
        const data = rangeToSlice(response.buffer);
        Music.init(path, allocator.dupe(u8, data) catch unreachable);
    } else if (std.mem.endsWith(u8, path, ".ogg")) {
        std.log.info("loaded ogg from: {s}", .{path});
        Sound.init(path, rangeToSlice(response.buffer));
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

    fn init(path: [:0]const u8, data: []const u8) void {
        const image = c.stbImage.loadFromMemory(data) catch unreachable;
        defer c.stbImage.unload(image);
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

const audio = @import("audio.zig");
pub const Sound = struct {
    var cache: std.StringHashMapUnmanaged(audio.Sound) = .empty;

    pub fn load(path: [:0]const u8) audio.Sound {
        const entry = cache.getOrPut(allocator, path) catch unreachable;
        if (entry.found_existing) return entry.value_ptr.*;

        send(path);
        return .{ .source = undefined, .valid = false };
    }

    pub fn init(path: [:0]const u8, data: []const u8) void {
        const stbAudio = c.stbAudio.loadFromMemory(data) catch unreachable;
        const info = c.stbAudio.getInfo(stbAudio);

        var sound = cache.getPtr(path).?;

        sound.channels = @intCast(info.channels);
        sound.sampleRate = @intCast(info.sample_rate);

        const size = c.stbAudio.getSampleCount(stbAudio) * sound.channels;
        sound.source = allocator.alloc(f32, size) catch unreachable;

        _ = c.stbAudio.fillSamples(stbAudio, sound.source, sound.channels);
        sound.valid = true;
    }

    pub fn deinit() void {
        var iterator = cache.valueIterator();
        while (iterator.next()) |value| allocator.free(value.source);
        cache.deinit(allocator);
    }
};

pub const Music = struct {
    pub fn load(path: [:0]const u8, loop: bool) audio.Music {
        if (audio.music) |m| {
            if (std.mem.eql(u8, m.path, path)) return audio.music.?;
        }

        send(path);
        return .{ .path = path, .loop = loop };
    }

    pub fn init(path: [:0]const u8, data: []const u8) void {
        const stbAudio = c.stbAudio.loadFromMemory(data) catch unreachable;
        const info = c.stbAudio.getInfo(stbAudio);
        const args = .{ info.sample_rate, info.channels, path };
        std.log.info("music sampleRate: {}, channels: {d}, path: {s}", args);
        audio.music.?.source = stbAudio;
        audio.music.?.data = data;
        audio.music.?.valid = true;
    }

    pub fn unload() void {
        c.stbAudio.unload(audio.music.?.source);
        audio.music.?.valid = false;
        if (audio.music.?.data.len != 0) {
            allocator.free(audio.music.?.data);
        }
    }
};
