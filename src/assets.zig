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
    Texture.cache.deinit(allocator);
    Sound.deinit();
    File.deinit();
    sk.fetch.shutdown();
}

pub fn loadTexture(path: [:0]const u8, size: math.Vector) gfx.Texture {
    return Texture.load(path, size);
}

pub const Texture = struct {
    var cache: std.StringHashMapUnmanaged(gfx.Texture) = .empty;

    pub fn load(path: [:0]const u8, size: math.Vector) gfx.Texture {
        const entry = cache.getOrPut(allocator, path) catch unreachable;
        if (entry.found_existing) return entry.value_ptr.*;

        send(path, callback);

        const image = sk.gfx.allocImage();
        entry.value_ptr.* = .{ .image = image, .area = .init(.zero, size) };
        return entry.value_ptr.*;
    }

    fn callback(responses: [*c]const sk.fetch.Response) callconv(.C) void {
        const response = extractResponse(responses);
        const data = response.data;

        const image = c.stbImage.loadFromMemory(data) catch unreachable;
        defer c.stbImage.unload(image);
        const texture = cache.getPtr(response.path).?;

        sk.gfx.initImage(texture.image, .{
            .width = image.width,
            .height = image.height,
            .data = init: {
                var imageData = sk.gfx.ImageData{};
                imageData.subimage[0][0] = sk.gfx.asRange(image.data);
                break :init imageData;
            },
        });
    }
};

const audio = @import("audio.zig");
pub const Sound = struct {
    var cache: std.StringHashMapUnmanaged(audio.Sound) = .empty;

    pub fn load(path: [:0]const u8) audio.Sound {
        const entry = cache.getOrPut(allocator, path) catch unreachable;
        if (entry.found_existing) return entry.value_ptr.*;

        send(path, callback);

        entry.value_ptr.* = .{ .source = undefined };

        return entry.value_ptr.*;
    }

    fn callback(responses: [*c]const sk.fetch.Response) callconv(.C) void {
        const response = extractResponse(responses);
        const data = response.data;

        const stbAudio = c.stbAudio.loadFromMemory(data) catch unreachable;
        const info = c.stbAudio.getInfo(stbAudio);

        var sound = cache.getPtr(response.path).?;

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

var loadingBuffer: [1.5 * 1024 * 1024]u8 = undefined;

const SkCallback = *const fn ([*c]const sk.fetch.Response) callconv(.C) void;
pub const Response = struct {
    allocator: std.mem.Allocator = undefined,
    index: AssetIndex = undefined,
    path: [:0]const u8,
    data: []const u8 = &.{},
};
const Loader = *const fn (response: Response) []const u8;

fn send(path: [:0]const u8, cb: SkCallback) void {
    std.log.info("loading {s}", .{path});

    const buffer = sk.fetch.asRange(&loadingBuffer);
    _ = sk.fetch.send(.{ .path = path, .callback = cb, .buffer = buffer });
}

fn extractResponse(responses: [*c]const sk.fetch.Response) Response {
    const res = responses[0];
    if (res.failed) {
        std.debug.panic("assets load failed, path: {s}", .{res.path});
    }

    const data: [*]const u8 = @ptrCast(res.data.ptr);
    const path = std.mem.span(res.path);
    std.log.info("loaded from: {s}", .{path});
    return .{ .path = path, .data = data[0..res.data.size] };
}

pub const AssetIndex = extern struct {
    state: enum(u16) { init, loading, loaded, unload } = .init,
    version: u16 = 0,
    index: u32,

    pub fn init(index: u32) AssetIndex {
        return .{ .index = index };
    }
};

const Cache = struct {
    index: AssetIndex,
    data: []const u8 = &.{},
    loader: Loader = undefined,

    pub fn init(index: u32, loader: Loader) Cache {
        return .{ .index = .init(index), .loader = loader };
    }
};

pub const File = struct {
    var cache: std.StringHashMapUnmanaged(Cache) = .empty;

    pub fn load(path: [:0]const u8, index: u32, loader: Loader) *Cache {
        const entry = cache.getOrPut(allocator, path) catch unreachable;
        if (entry.found_existing) return entry.value_ptr;

        entry.value_ptr.* = .{ .index = .init(index), .loader = loader };
        send(path, callback);
        entry.value_ptr.index.state = .loading;
        return entry.value_ptr;
    }

    fn callback(responses: [*c]const sk.fetch.Response) callconv(.C) void {
        var response = extractResponse(responses);
        const value = cache.getPtr(response.path).?;
        response.index = value.index;
        response.allocator = allocator;

        value.data = value.loader(response);
        value.index.state = .loaded;
    }

    pub fn deinit() void {
        var iterator = cache.valueIterator();
        while (iterator.next()) |value| allocator.free(value.data);
        cache.deinit(allocator);
    }
};
