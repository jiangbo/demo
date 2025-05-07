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
    File.deinit();
    sk.fetch.shutdown();
}

pub fn loadTexture(path: [:0]const u8, size: math.Vector) gfx.Texture {
    return Texture.load(path, size);
}

const AssetState = enum { init, loading, loaded, handled };

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

    pub fn load(path: [:0]const u8, index: u32) audio.Sound {
        const entry = cache.getOrPut(allocator, path) catch unreachable;
        if (entry.found_existing) return entry.value_ptr.*;

        const file = File.load(path, index, loader);
        if (file.handle.state == .loaded) {}

        entry.value_ptr.* = .{ .source = undefined };

        return entry.value_ptr.*;
    }

    fn loader(response: Response) []const u8 {
        const content = response.data;

        const stbAudio = c.stbAudio.Audio.init(content) catch unreachable;
        const info = stbAudio.getInfo();

        var sound = cache.getPtr(response.path).?;

        sound.channels = @intCast(info.channels);
        sound.sampleRate = @intCast(info.sample_rate);

        const size = stbAudio.getSampleCount() * sound.channels;
        sound.source = allocator.alloc(f32, size) catch unreachable;

        _ = stbAudio.fillSamples(sound.source, sound.channels);
        return sound.source;
    }
};

var loadingBuffer: [1.5 * 1024 * 1024]u8 = undefined;

const SkCallback = *const fn ([*c]const sk.fetch.Response) callconv(.C) void;
pub const Response = struct {
    allocator: std.mem.Allocator = undefined,
    index: usize = undefined,
    path: [:0]const u8,
    data: []const u8 = &.{},
};

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

pub const AssetHandle = extern struct {
    state: enum(u16) { init, loading, loaded, active, remove } = .init,
    version: u16 = 0,
    index: u32,

    pub fn init(index: u32) AssetHandle {
        return .{ .index = index };
    }

    pub fn isActive(self: *const AssetHandle) bool {
        return self.state == .active;
    }

    pub fn nextVersion(self: AssetHandle) AssetHandle {
        var result = self;
        result.version +%= 1;
        return result;
    }
};

pub const File = struct {
    const Handler = *const fn (response: Response) []const u8;
    const FileCache = struct {
        state: AssetState = .init,
        index: usize,
        data: []const u8 = &.{},
        handler: Handler = undefined,
    };

    var cache: std.StringHashMapUnmanaged(FileCache) = .empty;

    pub fn load(path: [:0]const u8, index: usize, handler: Handler) *FileCache {
        const entry = cache.getOrPut(allocator, path) catch unreachable;
        if (entry.found_existing) return entry.value_ptr;

        entry.value_ptr.* = .{ .index = index, .handler = handler };
        send(path, callback);
        entry.value_ptr.state = .loading;
        return entry.value_ptr;
    }

    fn callback(responses: [*c]const sk.fetch.Response) callconv(.C) void {
        var response = extractResponse(responses);
        const value = cache.getPtr(response.path) orelse return;
        response.index = value.index;
        response.allocator = allocator;

        value.state = .loaded;
        value.data = value.handler(response);
        value.state = .handled;
    }

    pub fn deinit() void {
        var iterator = cache.valueIterator();
        while (iterator.next()) |value| allocator.free(value.data);
        cache.deinit(allocator);
    }
};
