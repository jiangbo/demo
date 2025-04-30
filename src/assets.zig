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
    String.deinit();
    sk.fetch.shutdown();
}

pub fn loading() void {
    sk.fetch.dowork();
}

var loadingBuffer: [1.5 * 1024 * 1024]u8 = undefined;

const SkCallback = *const fn ([*c]const sk.fetch.Response) callconv(.C) void;
const Response = struct { path: [:0]const u8, data: []const u8 };

fn send(path: [:0]const u8, cb: SkCallback) void {
    std.log.info("loading {s}", .{path});

    const buffer = sk.fetch.asRange(&loadingBuffer);
    _ = sk.fetch.send(.{ .path = path, .callback = cb, .buffer = buffer });
}

fn extractResponses(responses: [*c]const sk.fetch.Response) Response {
    const res = responses[0];
    if (res.failed) {
        std.debug.panic("assets load failed, path: {s}", .{res.path});
    }

    const data: [*]const u8 = @ptrCast(res.data.ptr);
    const path = std.mem.span(res.path);
    std.log.info("loaded from: {s}", .{path});
    return .{ .path = path, .data = data[0..res.data.size] };
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
        const response = extractResponses(responses);
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
        const response = extractResponses(responses);
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

pub const String = struct {
    var cache: std.StringHashMapUnmanaged(StringCallback) = .empty;
    const Callback = *const fn ([]const u8) void;
    const StringCallback = struct { data: []const u8, callback: Callback };

    pub fn load(path: [:0]const u8, cb: Callback) void {
        const entry = cache.getOrPut(allocator, path) catch unreachable;
        if (entry.found_existing) return cb(entry.value_ptr.*.data);

        entry.value_ptr.* = .{ .data = &.{}, .callback = cb };
        send(path, callback);
    }

    fn callback(responses: [*c]const sk.fetch.Response) callconv(.C) void {
        const response = extractResponses(responses);
        const data = allocator.dupe(u8, response.data) catch unreachable;
        const value = cache.getPtr(response.path).?;
        value.data = data;
        value.callback(data);
    }

    pub fn deinit() void {
        var iterator = cache.valueIterator();
        while (iterator.next()) |value| allocator.free(value.data);
        cache.deinit(allocator);
    }
};
