const std = @import("std");

const sk = @import("sokol");
const c = @import("internal/c.zig");
const graphics = @import("graphics.zig");
const audio = @import("audio.zig");
const png = @import("internal/png.zig");
pub const memory = @import("internal/memory.zig");

const Image = graphics.Image;
const Path = [:0]const u8;
const assetRoot = "assets/";

var allocator: std.mem.Allocator = undefined;
pub var io: std.Io = undefined;
var imageCache: std.AutoHashMapUnmanaged(Id, graphics.Image) = .empty;
var maxFileSize: usize = 0;

pub fn init(io_: std.Io, gpa: std.mem.Allocator, maxSize: usize) void {
    io = io_;
    memory.init(gpa);
    allocator = memory.allocator.raw;
    maxFileSize = maxSize;

    sk.fetch.setup(.{
        .num_lanes = fileBuffer.len,
        .logger = .{ .func = sk.log.func },
        .allocator = @bitCast(memory.skAllocator),
    });
}

pub fn initCaches(allocator_: std.mem.Allocator) void {
    allocator, imageCache = .{ allocator_, .empty };
    atlas.cache = .empty;
    view.cache, file.cache = .{ .empty, .empty };
    sound.cache, music.cache = .{ .empty, .empty };
}

pub fn deinit() void {
    imageCache.deinit(allocator);
    atlas.deinit();
    view.cache.deinit(allocator);
    sound.cache.deinit(allocator);
    music.deinit();
    file.deinit();
    if (sk.fetch.valid()) sk.fetch.shutdown();
    for (&fileBuffer) |buffer| if (buffer.len != 0) free(buffer);
}

pub fn oomAlloc(comptime T: type, n: usize) []T {
    return allocator.alloc(T, n) catch oom();
}

pub fn oomDupe(comptime T: type, m: []const T) []T {
    return allocator.dupe(T, m) catch oom();
}

pub fn oomDupeZ(comptime T: type, m: []const T) [:0]T {
    return allocator.dupeZ(T, m) catch oom();
}

pub fn free(data: anytype) void {
    return allocator.free(data);
}

pub fn oom() noreturn {
    @panic("out of memory");
}

pub fn loadImage(path: Path, size: graphics.Vector2) Image {
    const entry = imageCache.getOrPut(allocator, id(path)) catch oom();
    if (!entry.found_existing) {
        const imageView = view.load(path);
        entry.value_ptr.* = .{ .view = imageView, .size = size };
    }
    return entry.value_ptr.*;
}

pub fn loadSound(path: Path, loop: bool) ?audio.Sound {
    return sound.load(path, loop);
}

pub fn loadMusic(path: Path, loop: bool) ?*c.stbAudio.Audio {
    return music.load(path, loop);
}

pub const Id = u32;
pub fn id(name: []const u8) Id {
    return std.hash.Fnv1a_32.hash(name);
}

pub fn loadAtlas(source: graphics.Atlas) void {
    atlas.load(source);
}

pub fn getImage(imageId: Id) ?graphics.Image {
    return imageCache.get(imageId);
}

pub fn getImageByPath(comptime path: Path) ?graphics.Image {
    return getImage(id(path));
}

pub fn putImage(imageId: Id, image: graphics.Image) void {
    imageCache.put(allocator, imageId, image) catch oom();
}

const atlas = struct {
    var cache: std.AutoHashMapUnmanaged(Id, Load) = .empty;

    const Load = struct {
        view: sk.gfx.View,
        size: graphics.Vector2,
        layers: usize,
        loaded: usize = 0,
        data: []u8,
    };

    const PageIndex = extern struct { atlasId: Id, layer: u32 };

    fn load(source: graphics.Atlas) void {
        const atlasId = id(source.imagePaths[0]);
        const entry = cache.getOrPut(allocator, atlasId) catch oom();
        if (entry.found_existing) return;

        const len: u32 = @intCast(source.imagePaths.len + source.images.len);
        imageCache.ensureUnusedCapacity(allocator, len) catch oom();

        const atlasView = sk.gfx.allocView();
        const pageCount = source.imagePaths.len;
        const pageSize: usize = @intFromFloat(source.size.x * source.size.y);
        entry.value_ptr.* = .{
            .view = atlasView,
            .size = source.size,
            .layers = pageCount,
            .data = oomAlloc(u8, pageSize * 4 * pageCount),
        };
        for (source.imagePaths, 0..) |path, i| {
            const pageIndex = PageIndex{
                .atlasId = atlasId,
                .layer = @intCast(i),
            };
            _ = file.load(path, @bitCast(pageIndex), handler);
            imageCache.putAssumeCapacity(id(path), .{
                .view = atlasView,
                .layer = @floatFromInt(i),
                .offset = .zero,
                .size = source.size,
            });
        }

        for (source.images) |image| {
            var img = image;
            img.view = atlasView;
            imageCache.putAssumeCapacity(image.view.id, img);
        }
    }

    fn handler(response: Response) []const u8 {
        const pageIndex: PageIndex = @bitCast(response.index);
        const loadContext = cache.getPtr(pageIndex.atlasId).?;
        const img = png.load(allocator, response.data) catch |err| {
            std.debug.panic("{s}: {}", .{ response.path, err });
        };
        defer allocator.free(img.data);

        const width: i32 = @intFromFloat(loadContext.size.x);
        const height: i32 = @intFromFloat(loadContext.size.y);
        std.debug.assert(img.width == width);
        std.debug.assert(img.height == height);

        const start = img.data.len * pageIndex.layer;
        const end = start + img.data.len;
        @memcpy(loadContext.data[start..end], img.data);
        loadContext.loaded += 1;

        if (loadContext.loaded == loadContext.layers) {
            sk.gfx.initView(loadContext.view, .{ .texture = .{
                .image = view.makeImage(
                    @intFromFloat(loadContext.size.x),
                    @intFromFloat(loadContext.size.y),
                    @intCast(loadContext.layers),
                    loadContext.data,
                ),
            } });
            allocator.free(loadContext.data);
            loadContext.data = &.{};
        }
        return &.{};
    }

    fn deinit() void {
        var iterator = cache.valueIterator();
        while (iterator.next()) |v| allocator.free(v.data);
        cache.deinit(allocator);
    }
};

pub const Icon = png.Image;
const IconHandler = fn (u64, Icon) void;
pub fn loadIcon(path: Path, handle: u64, handler: IconHandler) void {
    _ = file.load(path, handle, struct {
        fn callback(resp: Response) []const u8 {
            const icon = png.loadIcon(allocator, resp.data) catch |err| {
                std.debug.panic("{s}: {}", .{ resp.path, err });
            };
            defer allocator.free(icon.data);
            handler(resp.index, icon);
            return &.{};
        }
    }.callback);
}

const view = struct {
    var cache: std.AutoHashMapUnmanaged(Id, sk.gfx.View) = .empty;

    fn load(path: Path) sk.gfx.View {
        const imageView = sk.gfx.allocView();
        cache.put(allocator, id(path), imageView) catch oom();
        _ = file.load(path, imageView.id, handler);
        return imageView;
    }

    fn handler(resp: Response) []const u8 {
        const img = png.load(allocator, resp.data) catch |err| {
            std.debug.panic("{s}: {}", .{ resp.path, err });
        };
        defer allocator.free(img.data);
        const imageView: sk.gfx.View = .{ .id = @intCast(resp.index) };

        sk.gfx.initView(imageView, .{ .texture = .{
            .image = makeImage(img.width, img.height, 1, img.data),
        } });
        if (imageCache.getPtr(id(resp.path))) |image| {
            image.size = .{
                .x = @floatFromInt(img.width),
                .y = @floatFromInt(img.height),
            };
        }
        return &.{};
    }

    fn makeImage(w: i32, h: i32, layers: i32, data: anytype) sk.gfx.Image {
        return sk.gfx.makeImage(.{
            .width = w,
            .height = h,
            .type = .ARRAY,
            .num_slices = layers,
            .data = init: {
                var imageData = sk.gfx.ImageData{};
                imageData.mip_levels[0] = sk.gfx.asRange(data);
                break :init imageData;
            },
        });
    }
};

const sound = struct {
    var cache: std.AutoHashMapUnmanaged(Id, audio.Sound) = .empty;

    fn load(path: Path, loop: bool) ?audio.Sound {
        if (cache.get(id(path))) |value| return value;

        _ = file.load(path, if (loop) 1 else 0, handler);
        return null;
    }

    fn handler(resp: Response) []const u8 {
        const data = resp.data.items;

        const stbAudio = c.stbAudio.loadFromMemory(data);
        defer c.stbAudio.unload(stbAudio);
        const info = c.stbAudio.getInfo(stbAudio);

        const channels: i32 = @intCast(info.channels);
        const size = c.stbAudio.getSampleCount(stbAudio) * channels;
        const samples = oomAlloc(f32, @intCast(size));
        _ = c.stbAudio.fillSamples(stbAudio, samples, channels);

        cache.put(allocator, id(resp.path), .{
            .samples = samples,
            .channels = @intCast(channels),
        }) catch oom();
        // 冷加载首次补播只保留 loop，left/right 使用默认值。
        _ = audio.playSoundOption(resp.path, .{
            .loop = resp.index == 1,
        });
        return std.mem.sliceAsBytes(samples);
    }
};

const music = struct {
    var cache: std.AutoHashMapUnmanaged(Id, *c.stbAudio.Audio) = .empty;

    fn load(path: Path, loop: bool) ?*c.stbAudio.Audio {
        if (cache.get(id(path))) |value| return value;

        _ = file.load(path, if (loop) 1 else 0, handler);
        return null;
    }

    fn handler(resp: Response) []const u8 {
        const data = oomDupe(u8, resp.data.items);
        const stbAudio = c.stbAudio.loadFromMemory(data);
        cache.put(allocator, id(resp.path), stbAudio) catch oom();
        audio.playMusicOption(resp.path, resp.index == 1);
        return data;
    }

    pub fn deinit() void {
        var iterator = cache.valueIterator();
        while (iterator.next()) |v| c.stbAudio.unload(v.*);
        cache.deinit(allocator);
    }
};

pub const Response = struct {
    index: u64 = undefined,
    path: [:0]const u8,
    data: std.ArrayList(u8) = .empty,
};

var fileBuffer: [4][]u8 = @splat(&.{});
pub const file = struct {
    const FileState = enum { init, loading, loaded, handled };
    const Handler = *const fn (Response) []const u8;

    const FileCache = struct {
        state: FileState = .init,
        index: u64,
        managed: []const u8 = &.{},
        handler: Handler = undefined,
    };

    var cache: std.AutoHashMapUnmanaged(Id, FileCache) = .empty;

    pub fn load(path: Path, index: u64, handler: Handler) *FileCache {
        const entry = cache.getOrPut(allocator, id(path)) catch oom();
        if (entry.found_existing) {
            const value = entry.value_ptr;
            if (value.index != index or value.handler != handler) {
                std.debug.panic("asset path conflict: {s}", .{path});
            }
            return entry.value_ptr;
        }

        entry.value_ptr.* = .{ .index = index, .handler = handler };

        var buffer: [1024]u8 = undefined;
        std.debug.assert(buffer.len == sk.fetch.maxPath());
        const fmt = assetRoot ++ "{s}";
        const filePath = std.fmt.bufPrintZ(&buffer, fmt, .{path}) catch
            @panic("asset path too long");
        std.log.info("loading {s}", .{filePath});
        _ = sk.fetch.send(.{ .path = filePath, .callback = callback });

        entry.value_ptr.state = .loading;
        return entry.value_ptr;
    }

    fn callback(responses: [*c]const sk.fetch.Response) callconv(.c) void {
        const resp = responses[0];
        if (resp.failed) {
            const msg = "assets load failed, path: {s}, error code: {}";
            std.debug.panic(msg, .{ resp.path, resp.error_code });
        }
        if (resp.dispatched) {
            std.debug.assert(fileBuffer[resp.lane].len == 0);
            fileBuffer[resp.lane] = oomAlloc(u8, maxFileSize);
            const buffer = sk.fetch.asRange(fileBuffer[resp.lane]);
            sk.fetch.bindBuffer(resp.handle, buffer);
            return;
        }

        const filePath = std.mem.span(resp.path);
        std.log.info("loaded from: {s}", .{filePath});
        const path = filePath[assetRoot.len..];

        const value = cache.getPtr(id(path)).?;
        const response: Response = .{
            .index = value.index,
            .path = path,
            .data = .{
                .items = fileBuffer[resp.lane][0..resp.data.size],
                .capacity = fileBuffer[resp.lane].len,
            },
        };
        value.state = .loaded;
        value.managed = value.handler(response);
        value.state = .handled;
        free(fileBuffer[resp.lane]);
        fileBuffer[resp.lane] = &.{};
    }

    pub fn deinit() void {
        var iterator = cache.valueIterator();
        while (iterator.next()) |value| allocator.free(value.managed);
        cache.deinit(allocator);
    }
};

pub const Stats = struct {
    image: usize,
    file: usize,
    sound: usize,
    music: usize,
};

// 查询当前已加载并缓存的资源统计数据
pub fn queryStats() Stats {
    return .{
        .image = imageCache.count(),
        .file = file.cache.count(),
        .sound = sound.cache.count(),
        .music = music.cache.count(),
    };
}
