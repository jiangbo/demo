const std = @import("std");
const builtin = @import("builtin");

const sk = @import("sokol");
const math = @import("math.zig");
const assets = @import("assets.zig");
const input = @import("input.zig");
const text = @import("text.zig");

pub const Event = sk.app.Event;

const CountingAllocator = struct {
    child: std.mem.Allocator,
    used: usize,
    count: usize,

    pub fn init(child: std.mem.Allocator) CountingAllocator {
        return .{ .child = child, .used = 0, .count = 0 };
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
    fn allocs(c: *anyopaque, len: usize, a: A, r: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(c));
        const p = self.child.rawAlloc(len, a, r) orelse return null;
        self.count += 1;
        self.used += len;
        return p;
    }

    fn resize(c: *anyopaque, b: []u8, a: A, len: usize, r: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(c));
        const stable = self.child.rawResize(b, a, len, r);
        if (stable) {
            self.count += 1;
            self.used +%= len -% b.len;
        }
        return stable;
    }

    fn remap(c: *anyopaque, m: []u8, a: A, len: usize, r: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(c));
        const n = self.child.rawRemap(m, a, len, r) orelse return null;
        self.count += 1;
        self.used +%= len -% m.len;
        return n;
    }

    fn frees(c: *anyopaque, buf: []u8, a: A, r: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(c));
        self.used -= buf.len;
        return self.child.rawFree(buf, a, r);
    }
};

pub fn showCursor(show: bool) void {
    sk.app.showMouse(show);
}

pub fn toggleFullScreen() void {
    sk.app.toggleFullscreen();
}

/// 缩放模式枚举
pub const ScaleEnum = enum {
    none, // 无缩放，使用原始尺寸
    stretch, // 拉伸缩放，忽略宽高比填满屏幕
    fit, // 适配缩放，保持宽高比可能有黑边
    fill, // 填充缩放，保持宽高比可能超出屏幕
    integer, // 整数缩放，整数倍数（无滤镜失真）
};

pub const WindowInfo = struct {
    title: [:0]const u8, // 窗口标题
    size: math.Vector, // 窗口大小
    logicSize: ?math.Vector = null, // 逻辑大小，默认和窗口大小相同
    scaleEnum: ScaleEnum = .stretch, // 缩放模式
    disableIME: bool = true, // 禁用输入法
    alignment: math.Vector = .center, // 对齐方式
    maxFileSize: usize = 1 * 1024 * 1024, // 最大加载文件大小
};

pub fn call(object: anytype, comptime name: []const u8, args: anytype) void {
    if (@hasDecl(object, name)) @call(.auto, @field(object, name), args);
}

pub var size: math.Vector = .zero;
pub var clientSize: math.Vector = .zero;
pub var viewRect: math.Rect = undefined;
pub var countingAllocator: CountingAllocator = undefined;
pub var alignment: math.Vector2 = .center; // 默认居中
var scaleEnum: ScaleEnum = .stretch; // 当前缩放模式

pub extern "Imm32" fn ImmDisableIME(i32) std.os.windows.BOOL;

const root = @import("root");
pub fn run(allocs: std.mem.Allocator, info: WindowInfo) void {
    sk.time.setup();
    size = info.logicSize orelse info.size;
    viewRect = .init(.zero, size);
    alignment = info.alignment;
    scaleEnum = info.scaleEnum;
    countingAllocator = CountingAllocator.init(allocs);
    assets.init(countingAllocator.allocator(), info.maxFileSize);

    if (info.disableIME and builtin.os.tag == .windows) {
        _ = ImmDisableIME(-1);
    }

    sk.app.run(.{
        .window_title = info.title,
        .width = @intFromFloat(info.size.x),
        .height = @intFromFloat(info.size.y),
        .init_cb = windowInit,
        .event_cb = windowEvent,
        .frame_cb = windowFrame,
        .cleanup_cb = windowDeinit,
        .allocator = @bitCast(assets.skAllocator),
        .high_dpi = true,
    });
}

export fn windowInit() void {
    computeViewRect();
    sk.gfx.setup(.{
        .environment = sk.glue.environment(),
        .logger = .{ .func = sk.log.func },
        .allocator = assets.skAllocator,
    });
    math.setRandomSeed(sk.time.now());
    call(root, "init", .{});
}

pub var mouse: math.Vector = .zero;
pub var resized: bool = false;

export fn windowEvent(event: ?*const Event) void {
    if (event) |ev| {
        input.handle(ev);
        if (ev.type == .MOUSE_MOVE) {
            const position = input.mouse.raw.sub(viewRect.min);
            mouse = position.mul(size).div(viewRect.size);
        } else if (ev.type == .RESIZED) resized = true;

        call(root, "event", .{ev});
    }
}

pub fn computeViewRect() void {
    clientSize = .xy(sk.app.widthf(), sk.app.heightf());
    const ratio = clientSize.div(size);
    switch (scaleEnum) {
        .none => {
            viewRect = .init(clientSize.sub(size).mul(alignment), size);
        },
        .stretch => viewRect = .init(.zero, clientSize),
        .fit => {
            const minSize = size.scale(@min(ratio.x, ratio.y));
            const position = clientSize.sub(minSize).mul(alignment);
            viewRect = .init(position, minSize);
        },
        .fill => {
            const maxSize = size.scale(@max(ratio.x, ratio.y));
            const position = clientSize.sub(maxSize).mul(alignment);
            viewRect = .init(position, maxSize);
        },
        .integer => {
            const scale = @min(ratio.x, ratio.y);
            const usedScale = if (scale < 1) scale else @trunc(scale);
            const intSize = size.scale(usedScale);
            const position = clientSize.sub(intSize).mul(alignment);
            viewRect = .init(position, intSize);
        },
    }
    resized = false;
}

export fn windowFrame() void {
    sk.fetch.dowork();
    if (resized) computeViewRect();
    const delta: f32 = @floatCast(sk.app.frameDuration());
    call(root, "frame", .{delta});
    input.update();
}

export fn windowDeinit() void {
    call(root, "deinit", .{});
    sk.gfx.shutdown();
    assets.deinit();
}

pub fn statFileTime(path: [:0]const u8) i64 {
    const file = std.fs.cwd().openFile(path, .{}) catch return 0;
    defer file.close();

    const stat = file.stat() catch return 0;
    return @intCast(stat.mtime);
}

pub fn readBuffer(path: [:0]const u8, buffer: []u8) ![:0]u8 {
    const buf = buffer[0 .. buffer.len - 1];
    if (@import("builtin").target.os.tag == .emscripten) {
        const len = try readFromJs(path, buf);
        // 长度大于0，读完了内容，末尾补 0，返回 C 字符串。
        if (len > 0) return terminateBuffer(buffer, @intCast(len));
        // 长度小于0，没有读完，太长了。
        return error.BufferTooSmall;
    }
    const content = try std.fs.cwd().readFile(path, buf);
    return terminateBuffer(buffer, content.len);
}

pub fn readAll(path: [:0]const u8) ![:0]u8 {
    if (@import("builtin").target.os.tag == .emscripten) {
        var buffer: [1024]u8 = undefined;
        const len = try readFromJs(path, &buffer);
        // 长度大于0，读完了内容，直接分配返回。
        if (len > 0) return assets.oomDupeZ(u8, buffer[0..@intCast(len)]);

        // 长度小于0，没有读完，太长了，分配更大的空间再读一次。
        const fileLen: usize = @as(usize, @intCast(-len));
        const large = assets.oomAlloc(u8, fileLen + 1);
        _ = try readFromJs(path, large[0..fileLen]);
        return terminateBuffer(large, @intCast(fileLen));
    }
    const max = 1024 * 1024;
    return try std.fs.cwd().readFileAllocOptions( //
        assets.allocator, path, max, null, .of(u8), 0);
}

fn terminateBuffer(buffer: []u8, len: usize) [:0]u8 {
    buffer[len] = 0;
    return buffer[0..len :0];
}

fn readFromJs(path: [:0]const u8, content: []u8) !i32 {
    const value = @import("c.zig").em.my_add(1, 1);
    _ = value; // 强制 emscripten 链接器保留 em_js_file_load 所在的目标文件
    const len = @import("c.zig").em.em_js_file_load(path.ptr, //
        content.ptr, @intCast(content.len));
    // JS 端约定：0 表示不存在，正数/负数都表示文件总长度。
    if (len == 0) return error.FileNotFound;
    return len;
}

pub fn saveAll(path: [:0]const u8, content: []const u8) !void {
    if (@import("builtin").target.os.tag == .emscripten) {
        return @import("c.zig").em.em_js_file_save(path.ptr, //
            content.ptr, @intCast(content.len));
    }

    const cwd = std.fs.cwd();

    if (std.fs.path.dirname(path)) |dir| {
        try cwd.makePath(dir);
    }

    var file = try cwd.createFile(path, .{ .truncate = true });
    defer file.close();

    try file.writeAll(content);
}

pub fn exit() void {
    sk.app.requestQuit();
}

pub const Cursor = sk.app.MouseCursor;
pub const useMouseIcon = sk.app.setMouseCursor;
pub const CursorDesc = extern struct {
    cursor: Cursor = .CUSTOM_1,
    offset: extern struct { x: i16 = 0, y: i16 = 0 } = .{},
    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf(u64));
    }
};
pub fn bindMouseIcon(path: [:0]const u8, desc: CursorDesc) void {
    assets.loadIcon(path, @bitCast(desc), mouseCallback);
}

fn mouseCallback(handle: u64, icon: assets.Icon) void {
    const cursorDesc: CursorDesc = @bitCast(handle);
    _ = sk.app.bindMouseCursorImage(cursorDesc.cursor, .{
        .pixels = @bitCast(sk.gfx.asRange(icon.data)),
        .width = icon.width,
        .height = icon.height,
        .cursor_hotspot_x = cursorDesc.offset.x,
        .cursor_hotspot_y = cursorDesc.offset.y,
    });
}

pub fn bindAndUseMouseIcon(path: [:0]const u8, desc: CursorDesc) void {
    assets.loadIcon(path, @bitCast(desc), struct {
        fn callback(handle: u64, icon: assets.Icon) void {
            mouseCallback(handle, icon);
            const cursorDesc: CursorDesc = @bitCast(handle);
            useMouseIcon(cursorDesc.cursor);
        }
    }.callback);
}

pub fn useWindowIcon(path: [:0]const u8) void {
    assets.loadIcon(path, 0, struct {
        fn callback(icon: assets.Icon) void {
            var desc: sk.app.IconDesc = .{};
            desc.images[0] = .{
                .pixels = @bitCast(sk.gfx.asRange(icon.data)),
                .width = icon.width,
                .height = icon.height,
            };
            sk.app.setIcon(desc);
        }
    }.callback);
}

pub fn drawCenter(str: text.String, y: f32, option: text.Option) void {
    const textSize = text.measure(str, option);
    const pos = size.mul(.init(0.5, y)).sub(.xy(textSize.x / 2, 0));
    text.drawString(str, pos, option);
}
