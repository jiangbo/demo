const std = @import("std");
const sk = @import("sokol");
const math = @import("math.zig");
const assets = @import("assets.zig");
const audio = @import("audio.zig");
const input = @import("input.zig");
const font = @import("font.zig");
const gpu = @import("gpu.zig");

pub const Event = sk.app.Event;

pub const Timer = struct {
    duration: f32,
    elapsed: f32 = 0,

    pub fn init(duration: f32) Timer {
        return Timer{ .duration = duration };
    }

    pub fn update(self: *Timer, delta: f32) void {
        if (self.elapsed < self.duration) self.elapsed += delta;
    }

    pub fn isRunningAfterUpdate(self: *Timer, delta: f32) bool {
        self.update(delta);
        return self.isRunning();
    }

    pub fn isFinishedAfterUpdate(self: *Timer, delta: f32) bool {
        return !self.isRunningAfterUpdate(delta);
    }

    pub fn isRunning(self: *const Timer) bool {
        return self.elapsed < self.duration;
    }

    pub fn restart(self: *Timer) void {
        self.elapsed = self.elapsed - self.duration;
    }

    pub fn stop(self: *Timer) void {
        self.elapsed = self.duration;
    }

    pub fn reset(self: *Timer) void {
        self.elapsed = 0;
    }
};

const CountingAllocator = struct {
    child: std.mem.Allocator,
    used: u64 = 0,
    count: u64 = 0,

    pub fn init(child: std.mem.Allocator) CountingAllocator {
        return .{ .child = child };
    }

    pub fn allocator(self: *CountingAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    const A = std.mem.Alignment;
    fn alloc(c: *anyopaque, len: usize, a: A, r: usize) ?[*]u8 {
        var self: *CountingAllocator = @ptrCast(@alignCast(c));
        const p = self.child.rawAlloc(len, a, r) orelse return null;
        self.count += 1;
        self.used += len;
        return p;
    }

    fn resize(c: *anyopaque, b: []u8, a: A, len: usize, r: usize) bool {
        var self: *CountingAllocator = @ptrCast(@alignCast(c));
        const stable = self.child.rawResize(b, a, len, r);
        if (stable) {
            self.count += 1;
            self.used += len;
            self.used -= b.len;
        }
        return stable;
    }

    fn remap(c: *anyopaque, m: []u8, a: A, len: usize, r: usize) ?[*]u8 {
        var self: *CountingAllocator = @ptrCast(@alignCast(c));
        const n = self.child.rawRemap(m, a, len, r) orelse return null;
        if (n != m.ptr) {
            self.used -= m.len;
            self.used += len;
        }
        return n;
    }

    fn free(c: *anyopaque, buf: []u8, a: A, r: usize) void {
        var self: *CountingAllocator = @ptrCast(@alignCast(c));
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

pub const WindowInfo = struct {
    title: [:0]const u8,
    size: math.Vector,
};

pub fn call(object: anytype, comptime name: []const u8, args: anytype) void {
    if (@hasDecl(object, name)) @call(.auto, @field(object, name), args);
}

pub var size: math.Vector = .zero;
pub var displayArea: math.Rectangle = undefined;
pub var allocator: std.mem.Allocator = undefined;
pub var countingAllocator: CountingAllocator = undefined;
var timer: std.time.Timer = undefined;

const root = @import("root");
pub fn run(alloc: std.mem.Allocator, info: WindowInfo) void {
    timer = std.time.Timer.start() catch unreachable;
    size = info.size;
    displayArea = .init(.zero, size);
    countingAllocator = CountingAllocator.init(alloc);
    allocator = countingAllocator.allocator();

    sk.app.run(.{
        .window_title = info.title,
        .width = @as(i32, @intFromFloat(size.x)),
        .height = @as(i32, @intFromFloat(size.y)),
        .high_dpi = true,
        .init_cb = windowInit,
        .event_cb = windowEvent,
        .frame_cb = windowFrame,
        .cleanup_cb = windowDeinit,
    });
}

export fn windowInit() void {
    assets.init(allocator);

    sk.gfx.setup(.{
        .environment = sk.glue.environment(),
        .logger = .{ .func = sk.log.func },
    });
    gpu.init();

    math.setRandomSeed(timer.lap());
    call(root, "init", .{});
}

pub var mouseMoved: bool = false;
pub var mousePosition: math.Vector = .zero;

export fn windowEvent(event: ?*const Event) void {
    if (event) |ev| {
        input.event(ev);
        if (ev.type == .MOUSE_MOVE) {
            mouseMoved = true;
            const pos = input.mousePosition.sub(displayArea.min);
            mousePosition = pos.mul(size).div(displayArea.size());
        }
        call(root, "event", .{ev});
    }
}

pub fn screenSize() math.Vector {
    return .{ .x = sk.app.widthf(), .y = sk.app.heightf() };
}

pub fn keepAspectRatio() void {
    const ratio = screenSize().div(size);
    const minSize = size.scale(@min(ratio.x, ratio.y));
    const pos = screenSize().sub(minSize).scale(0.5);
    displayArea = .init(pos, minSize);
    sk.gfx.applyViewportf(pos.x, pos.y, minSize.x, minSize.y, true);
}

var frameRateTimer: Timer = .init(1);
var frameRateCount: u32 = 0;
var usedDelta: u64 = 0;
pub var frameRate: u32 = 0;
pub var frameDeltaPerSecond: f32 = 0;
pub var usedDeltaPerSecond: f32 = 0;

export fn windowFrame() void {
    const deltaNano: f32 = @floatFromInt(timer.lap());
    const delta = deltaNano / std.time.ns_per_s;
    defer usedDelta = timer.read();

    if (frameRateTimer.isFinishedAfterUpdate(delta)) {
        frameRateTimer.restart();
        frameRate = frameRateCount;
        frameRateCount = 1;
        frameDeltaPerSecond = delta * 1000;
        const deltaUsed: f32 = @floatFromInt(usedDelta);
        usedDeltaPerSecond = deltaUsed / std.time.ns_per_ms;
    } else frameRateCount += 1;

    sk.fetch.dowork();
    gpu.begin(.{ .a = 1 });
    // gpu.begin(.{ .r = 1, .b = 1, .a = 1 });
    call(root, "frame", .{delta});
    gpu.end();
    input.lastKeyState = input.keyState;
    input.lastButtonState = input.buttonState;
    mouseMoved = false;
}

export fn windowDeinit() void {
    call(root, "deinit", .{});
    sk.gfx.shutdown();
    assets.deinit();
}

pub fn readAll(alloc: std.mem.Allocator, path: []const u8) [:0]u8 {
    return doReadAll(alloc, path) catch @panic("file error");
}
fn doReadAll(alloc: std.mem.Allocator, path: []const u8) ![:0]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const endPos = try file.getEndPos();
    const content = try alloc.allocSentinel(u8, endPos, 0);
    const bytes = try file.readAll(content);
    std.debug.assert(bytes == endPos);
    return content;
}

pub fn exit() void {
    sk.app.requestQuit();
}

pub const File = assets.File;
pub const loadTexture = assets.loadTexture;
pub const playSound = audio.playSound;
pub const playMusic = audio.playMusic;
pub const stopMusic = audio.stopMusic;
pub const random = math.random;
pub const isKeyDown = input.isKeyDown;
pub const isAnyKeyDown = input.isAnyKeyDown;
pub const isKeyRelease = input.isKeyRelease;
pub const isAnyKeyRelease = input.isAnyKeyRelease;
pub const isButtonRelease = input.isButtonRelease;
pub const pressed = isKeyRelease;
pub const pressedAny = isAnyKeyRelease;
pub const pressedButton = isButtonRelease;
pub const pressedAnyButton = input.isAnyButtonRelease;
pub const initFont = font.init;
