const std = @import("std");

const sk = @import("sokol");
const c = @import("c.zig");
const graphics = @import("graphics.zig");
const audio = @import("audio.zig");
const png = @import("extend/png.zig");

const Image = graphics.Image;
const Path = [:0]const u8;

pub const CountingAllocator = struct {
    child: std.mem.Allocator,
    used: usize,
    max: usize,
    count: usize,

    pub fn init(child: std.mem.Allocator) CountingAllocator {
        return .{ .child = child, .used = 0, .max = 0, .count = 0 };
    }

    pub fn allocator(self: *CountingAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = allocs,
                .resize = resize,
                .remap = remap,
                .free = frees,
            },
        };
    }

    const A = std.mem.Alignment;
    fn allocs(ctx: *anyopaque, len: usize, a: A, r: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const p = self.child.rawAlloc(len, a, r) orelse return null;
        self.count += 1;
        self.used += len;
        self.max = @max(self.max, self.used);
        return p;
    }

    fn resize(ctx: *anyopaque, b: []u8, a: A, len: usize, r: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const stable = self.child.rawResize(b, a, len, r);
        if (stable) {
            self.count += 1;
            self.used +%= len -% b.len;
            self.max = @max(self.max, self.used);
        }
        return stable;
    }

    fn remap(ctx: *anyopaque, m: []u8, a: A, len: usize, r: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const n = self.child.rawRemap(m, a, len, r) orelse return null;
        self.count += 1;
        self.used +%= len -% m.len;
        self.max = @max(self.max, self.used);
        return n;
    }

    fn frees(ctx: *anyopaque, buf: []u8, a: A, r: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.used -= buf.len;
        return self.child.rawFree(buf, a, r);
    }
};

pub var allocator: std.mem.Allocator = undefined;
pub var skAllocator: sk.gfx.Allocator = undefined;
pub var io: std.Io = undefined;
pub var memory: CountingAllocator = undefined; // 统计全局资源内存
var imageCache: std.AutoHashMapUnmanaged(Id, graphics.Image) = .empty;

pub fn init(io_: std.Io, gpa: std.mem.Allocator, maxSize: usize) void {
    io = io_;
    memory = CountingAllocator.init(gpa);
    allocator = memory.allocator();
    skAllocator = .{ .alloc_fn = sk_alloc, .free_fn = sk_free };

    sk.fetch.setup(.{
        .num_lanes = fileBuffer.len,
        .logger = .{ .func = sk.log.func },
        .allocator = @bitCast(skAllocator),
    });
    for (&fileBuffer) |*buffer| buffer.* = oomAlloc(u8, maxSize);
}

pub fn initCaches(allocator1: std.mem.Allocator) void {
    allocator, imageCache = .{ allocator1, .empty };
    View.cache, File.cache = .{ .empty, .empty };
    Sound.cache, Music.cache = .{ .empty, .empty };
}

fn sk_alloc(len: usize, _: ?*anyopaque) callconv(.c) ?*anyopaque {
    return stb_alloc(len) orelse oom();
}

fn sk_free(ptr: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
    stb_free(ptr);
}

// stb 的 C 接口 free 不传长度，所以在返回指针前面存一份长度。
const stbAlign = std.mem.Alignment.of(std.c.max_align_t);
const stbHeaderSize = std.mem.alignForward(usize, //
    @sizeOf(usize), @alignOf(std.c.max_align_t));

fn stbSlice(ptr: *anyopaque) []align(@alignOf(std.c.max_align_t)) u8 {
    const base = @as([*]u8, @ptrCast(ptr)) - stbHeaderSize;
    const header: *usize = @ptrCast(@alignCast(base));
    return @alignCast(base[0 .. stbHeaderSize + header.*]);
}

export fn stb_alloc(len: usize) ?*anyopaque {
    if (len == 0) return null;
    const base = allocator.rawAlloc(stbHeaderSize + len, //
        stbAlign, @returnAddress()) orelse return null;
    @as(*usize, @ptrCast(@alignCast(base))).* = len;
    return @ptrCast(base + stbHeaderSize);
}

export fn stb_realloc(ptr: ?*anyopaque, len: usize) ?*anyopaque {
    const oldPtr = ptr orelse return stb_alloc(len);
    if (len == 0) {
        stb_free(oldPtr);
        return null;
    }

    const old = stbSlice(oldPtr);
    const newLen = stbHeaderSize + len;
    const newSlice = allocator.realloc(old, newLen) catch return null;
    @as(*usize, @ptrCast(@alignCast(newSlice.ptr))).* = len;
    return @ptrCast(newSlice.ptr + stbHeaderSize);
}

export fn stb_free(ptr: ?*anyopaque) void {
    const p = ptr orelse return;
    allocator.rawFree(stbSlice(p), stbAlign, @returnAddress());
}

pub fn deinit() void {
    imageCache.deinit(allocator);
    View.cache.deinit(allocator);
    Sound.cache.deinit(allocator);
    Music.deinit();
    File.deinit();
    if (sk.fetch.valid()) sk.fetch.shutdown();
    for (&fileBuffer) |buffer| free(buffer);
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
        const view = View.load(path);
        entry.value_ptr.* = .{ .view = view, .size = size };
    }
    return entry.value_ptr.*;
}

pub fn loadSound(path: Path, loop: bool) ?audio.Sound {
    return Sound.load(path, loop);
}

pub fn loadMusic(path: Path, loop: bool) ?*c.stbAudio.Audio {
    return Music.load(path, loop);
}

pub const Id = u32;
pub fn id(name: []const u8) Id {
    return std.hash.Fnv1a_32.hash(name);
}

pub fn loadAtlas(atlas: graphics.Atlas) void {
    const size: u32 = @intCast(atlas.images.len + 1); // 多包含一张图集
    imageCache.ensureUnusedCapacity(allocator, size) catch oom();
    var image = loadImage(atlas.imagePath, atlas.size);

    for (atlas.images) |atlasImage| {
        image.offset = atlasImage.rect.min;
        image.size = atlasImage.rect.size;
        imageCache.putAssumeCapacity(atlasImage.id, image);
    }
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

pub const Icon = png.Image;
const IconHandler = fn (u64, Icon) void;
pub fn loadIcon(path: Path, handle: u64, handler: IconHandler) void {
    _ = File.load(path, handle, struct {
        fn callback(response: Response) []const u8 {
            const icon = png.load(allocator, response.data) catch |err| {
                std.debug.panic("{s}: {}", .{ response.path, err });
            };
            defer allocator.free(icon.data);
            handler(response.index, icon);
            return &.{};
        }
    }.callback);
}

const View = struct {
    var cache: std.AutoHashMapUnmanaged(Id, sk.gfx.View) = .empty;

    fn load(path: Path) sk.gfx.View {
        const view = sk.gfx.allocView();
        cache.put(allocator, id(path), view) catch oom();
        _ = File.load(path, view.id, handler);
        return view;
    }

    fn handler(response: Response) []const u8 {
        const img = png.load(allocator, response.data) catch |err| {
            std.debug.panic("{s}: {}", .{ response.path, err });
        };
        defer allocator.free(img.data);
        const view: sk.gfx.View = .{ .id = @intCast(response.index) };

        sk.gfx.initView(view, .{ .texture = .{
            .image = makeImage(img.width, img.height, img.data),
        } });
        if (imageCache.getPtr(id(response.path))) |image| {
            image.size = .{
                .x = @floatFromInt(img.width),
                .y = @floatFromInt(img.height),
            };
        }
        return &.{};
    }

    fn makeImage(w: i32, h: i32, data: anytype) sk.gfx.Image {
        return sk.gfx.makeImage(.{
            .width = w,
            .height = h,
            .type = .ARRAY,
            .data = init: {
                var imageData = sk.gfx.ImageData{};
                imageData.mip_levels[0] = sk.gfx.asRange(data);
                break :init imageData;
            },
        });
    }
};

const Sound = struct {
    var cache: std.AutoHashMapUnmanaged(Id, audio.Sound) = .empty;

    fn load(path: Path, loop: bool) ?audio.Sound {
        if (cache.get(id(path))) |value| return value;

        _ = File.load(path, if (loop) 1 else 0, handler);
        return null;
    }

    fn handler(response: Response) []const u8 {
        const data = response.data;

        const stbAudio = c.stbAudio.loadFromMemory(data);
        defer c.stbAudio.unload(stbAudio);
        const info = c.stbAudio.getInfo(stbAudio);

        const channels: i32 = @intCast(info.channels);
        const size = c.stbAudio.getSampleCount(stbAudio) * channels;
        const samples = oomAlloc(f32, @intCast(size));
        _ = c.stbAudio.fillSamples(stbAudio, samples, channels);

        cache.put(allocator, id(response.path), .{
            .samples = samples,
            .channels = @intCast(channels),
        }) catch oom();
        // 冷加载首次补播只保留 loop，left/right 使用默认值。
        _ = audio.playSoundOption(response.path, .{
            .loop = response.index == 1,
        });
        return std.mem.sliceAsBytes(samples);
    }
};

const Music = struct {
    var cache: std.AutoHashMapUnmanaged(Id, *c.stbAudio.Audio) = .empty;

    fn load(path: Path, loop: bool) ?*c.stbAudio.Audio {
        if (cache.get(id(path))) |value| return value;

        _ = File.load(path, if (loop) 1 else 0, handler);
        return null;
    }

    fn handler(response: Response) []const u8 {
        const data = oomDupe(u8, response.data);
        const stbAudio = c.stbAudio.loadFromMemory(data);
        cache.put(allocator, id(response.path), stbAudio) catch oom();
        audio.playMusicOption(response.path, response.index == 1);
        return data;
    }

    pub fn deinit() void {
        var iterator = cache.valueIterator();
        while (iterator.next()) |v| c.stbAudio.unload(v.*);
        cache.deinit(allocator);
    }
};

const SkCallback = *const fn ([*c]const sk.fetch.Response) callconv(.C) void;
pub const Response = struct {
    index: u64 = undefined,
    path: [:0]const u8,
    data: []const u8 = &.{},
};

var fileBuffer: [4][]u8 = @splat(&.{});
pub const File = struct {
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

        std.log.info("loading {s}", .{path});
        _ = sk.fetch.send(.{
            .path = path,
            .callback = callback,
        });

        entry.value_ptr.state = .loading;
        return entry.value_ptr;
    }

    fn callback(responses: [*c]const sk.fetch.Response) callconv(.c) void {
        const res = responses[0];
        if (res.failed) {
            const msg = "assets load failed, path: {s}, error code: {}";
            std.debug.panic(msg, .{ res.path, res.error_code });
        }
        if (res.dispatched) {
            const buffer = sk.fetch.asRange(fileBuffer[res.lane]);
            sk.fetch.bindBuffer(res.handle, buffer);
            return;
        }

        const path = std.mem.span(res.path);
        std.log.info("loaded from: {s}", .{path});

        const value = cache.getPtr(id(path)) orelse return;
        const data = @as([*]const u8, @ptrCast(res.data.ptr));
        const response: Response = .{
            .index = value.index,
            .path = path,
            .data = data[0..res.data.size],
        };

        value.state = .loaded;
        value.managed = value.handler(response);
        value.state = .handled;
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
        .file = File.cache.count(),
        .sound = Sound.cache.count(),
        .music = Music.cache.count(),
    };
}
