const std = @import("std");

const sk = @import("sokol");
const c = @import("c.zig");
const graphics = @import("graphics.zig");
const audio = @import("audio.zig");

const Image = graphics.Image;

var allocator: std.mem.Allocator = undefined;
var imageCache: std.AutoHashMapUnmanaged(Id, Image) = .empty;

pub fn init(allocator1: std.mem.Allocator) void {
    allocator = allocator1;
    sk.fetch.setup(.{ .logger = .{ .func = sk.log.func } });
}

pub fn deinit() void {
    imageCache.deinit(allocator);
    Texture.cache.deinit(allocator);
    Sound.cache.deinit(allocator);
    Music.deinit();
    File.deinit();
    sk.fetch.shutdown();
}

pub fn alloc(comptime T: type, n: usize) []T {
    return allocator.alloc(T, n) catch oom();
}

pub fn dupe(comptime T: type, m: []const T) []T {
    return allocator.dupe(T, m) catch oom();
}

pub fn free(memory: anytype) void {
    return allocator.free(memory);
}

pub fn oom() noreturn {
    @panic("out of memory");
}

pub fn loadImage(path: [:0]const u8, width: f32, height: f32) Image {
    const entry = imageCache.getOrPut(allocator, id(path)) catch oom();
    if (!entry.found_existing) {
        entry.value_ptr.* = .{
            .texture = Texture.load(path),
            .area = .init(.zero, .init(width, height)),
        };
    }
    return entry.value_ptr.*;
}

pub fn loadSound(path: [:0]const u8, loop: bool) *audio.Sound {
    return Sound.load(path, loop);
}

pub fn loadMusic(path: [:0]const u8, loop: bool) *audio.Music {
    return Music.load(path, loop);
}

pub const Id = u32;
pub fn id(name: []const u8) Id {
    return std.hash.Fnv1a_32.hash(name);
}

pub fn loadAtlas(atlas: graphics.Atlas) void {
    const size: u32 = @intCast(atlas.images.len + 1); // 多包含一张图集
    imageCache.ensureUnusedCapacity(allocator, size) catch oom();
    var image = loadImage(atlas.imagePath, atlas.size.x, atlas.size.y);

    for (atlas.images) |atlasImage| {
        image.area = atlasImage.area;
        imageCache.putAssumeCapacity(atlasImage.id, image);
    }
}

pub fn createWhiteImage(comptime key: [:0]const u8) Id {
    const data: [64]u8 = @splat(0xFF);
    const image = Texture.makeImage(4, 4, &data);
    const view = sk.gfx.makeView(.{ .texture = .{ .image = image } });
    Texture.cache.put(allocator, key, view) catch oom();
    imageCache.put(allocator, comptime id(key), .{
        .texture = view,
        .area = .init(.zero, .{ .x = 4, .y = 4 }),
    }) catch oom();
    return comptime id(key);
}

pub fn getImage(imageId: Id) graphics.Image {
    return imageCache.get(imageId).?;
}

pub const Icon = c.stbImage.Image;
pub fn loadIcon(path: [:0]const u8, handler: fn (Icon) void) void {
    _ = File.load(path, 0, struct {
        fn callback(response: Response) []const u8 {
            const icon = c.stbImage.loadFromMemory(response.data);
            handler(icon);
            return dupe(u8, icon.data);
        }
    }.callback);
}

pub const Texture = struct {
    var cache: std.StringHashMapUnmanaged(graphics.Texture) = .empty;

    pub fn load(path: [:0]const u8) graphics.Texture {
        const view = sk.gfx.allocView();
        cache.put(allocator, path, view) catch oom();
        _ = File.load(path, view.id, handler);
        return view;
    }

    fn handler(response: Response) []const u8 {
        const data = response.data;

        const image = c.stbImage.loadFromMemory(data);
        defer c.stbImage.unload(image);
        const texture = cache.get(response.path).?;

        sk.gfx.initView(texture, .{ .texture = .{
            .image = makeImage(image.width, image.height, image.data),
        } });
        return &.{};
    }

    fn makeImage(w: i32, h: i32, data: []const u8) sk.gfx.Image {
        return sk.gfx.makeImage(.{
            .width = w,
            .height = h,
            .data = init: {
                var imageData = sk.gfx.ImageData{};
                imageData.mip_levels[0] = sk.gfx.asRange(data);
                break :init imageData;
            },
        });
    }
};

const Sound = struct {
    var cache: std.StringHashMapUnmanaged(audio.Sound) = .empty;

    fn load(path: [:0]const u8, loop: bool) *audio.Sound {
        const entry = cache.getOrPut(allocator, path) catch oom();
        if (entry.found_existing) return entry.value_ptr;

        const index = audio.allocSoundBuffer();
        entry.value_ptr.* = .{ .loop = loop, .handle = index };
        _ = File.load(path, index, handler);
        return entry.value_ptr;
    }

    fn handler(response: Response) []const u8 {
        const data = response.data;

        const stbAudio = c.stbAudio.loadFromMemory(data);
        defer c.stbAudio.unload(stbAudio);
        const info = c.stbAudio.getInfo(stbAudio);

        var sound = cache.getPtr(response.path).?;

        sound.channels = @intCast(info.channels);

        const size = c.stbAudio.getSampleCount(stbAudio) * sound.channels;
        sound.source = allocator.alloc(f32, size) catch unreachable;

        _ = c.stbAudio.fillSamples(stbAudio, sound.source, sound.channels);

        sound.state = .playing;
        audio.sounds[response.index] = sound.*;
        return @ptrCast(sound.source);
    }
};

const Music = struct {
    var cache: std.StringHashMapUnmanaged(audio.Music) = .empty;

    fn load(path: [:0]const u8, loop: bool) *audio.Music {
        const entry = cache.getOrPut(allocator, path) catch oom();
        if (entry.found_existing) return entry.value_ptr;

        _ = File.load(path, 0, handler);
        entry.value_ptr.* = .{ .loop = loop };
        return entry.value_ptr;
    }

    fn handler(response: Response) []const u8 {
        const data = dupe(u8, response.data);
        const stbAudio = c.stbAudio.loadFromMemory(data);

        const value = cache.getPtr(response.path).?;
        value.source = stbAudio;
        value.state = .playing;
        audio.music = value.*;
        return data;
    }

    pub fn deinit() void {
        var iterator = cache.valueIterator();
        while (iterator.next()) |value| {
            if (value.state != .init) {
                // 不释放没有加载的资源
                c.stbAudio.unload(value.source);
            }
        }
        cache.deinit(allocator);
    }
};

var loadingBuffer: [5 * 1024 * 1024]u8 = undefined;

const SkCallback = *const fn ([*c]const sk.fetch.Response) callconv(.C) void;
pub const Response = struct {
    allocator: std.mem.Allocator = undefined,
    index: usize = undefined,
    path: [:0]const u8,
    data: []const u8 = &.{},
};

pub const File = struct {
    const FileState = enum { init, loading, loaded, handled };
    const Handler = *const fn (Response) []const u8;

    const FileCache = struct {
        state: FileState = .init,
        index: usize,
        data: []const u8 = &.{},
        handler: Handler = undefined,
    };

    var cache: std.StringHashMapUnmanaged(FileCache) = .empty;

    pub fn load(path: [:0]const u8, index: usize, handler: Handler) *FileCache {
        const entry = cache.getOrPut(allocator, path) catch oom();
        if (entry.found_existing) return entry.value_ptr;

        entry.value_ptr.* = .{ .index = index, .handler = handler };

        std.log.info("loading {s}", .{path});
        const buffer = sk.fetch.asRange(&loadingBuffer);
        _ = sk.fetch.send(.{
            .path = path,
            .callback = callback,
            .buffer = buffer,
        });

        entry.value_ptr.state = .loading;
        return entry.value_ptr;
    }

    fn callback(responses: [*c]const sk.fetch.Response) callconv(.c) void {
        const res = responses[0];
        if (res.failed) {
            std.debug.panic("assets load failed, path: {s}", .{res.path});
        }

        const path = std.mem.span(res.path);
        std.log.info("loaded from: {s}", .{path});

        const value = cache.getPtr(path) orelse return;
        const data = @as([*]const u8, @ptrCast(res.data.ptr));
        const response: Response = .{
            .allocator = allocator,
            .index = value.index,
            .path = path,
            .data = data[0..res.data.size],
        };

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
