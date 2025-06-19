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

pub fn showCursor(show: bool) void {
    sk.app.showMouse(show);
}

pub const WindowInfo = struct {
    title: [:0]const u8,
    size: math.Vector,
};

pub fn call(object: anytype, comptime name: []const u8, args: anytype) void {
    if (@hasDecl(object, name)) @call(.auto, @field(object, name), args);
}

pub var size: math.Vector = .zero;
pub var allocator: std.mem.Allocator = undefined;
var timer: std.time.Timer = undefined;

const root = @import("root");
pub fn run(alloc: std.mem.Allocator, info: WindowInfo) void {
    timer = std.time.Timer.start() catch unreachable;
    size = info.size;
    allocator = alloc;

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

pub var mousePosition: math.Vector = .zero;

export fn windowEvent(event: ?*const Event) void {
    if (event) |ev| {
        input.event(ev);
        mousePosition = input.mousePosition.mul(size.div(actualSize()));
        call(root, "event", .{ev});
    }
}

pub fn actualSize() math.Vector {
    return .{ .x = sk.app.widthf(), .y = sk.app.heightf() };
}

pub fn keepAspectRatio() void {
    const ratio = actualSize().div(size);
    const minSize = size.scale(@min(ratio.x, ratio.y));
    sk.gfx.applyViewportf(0, 0, minSize.x, minSize.y, true);
}

var frameRateTimer: Timer = .init(1);
var frameRateCount: u32 = 0;
pub var frameRate: u32 = 0;

export fn windowFrame() void {
    const deltaNano: f32 = @floatFromInt(timer.lap());
    const delta = deltaNano / std.time.ns_per_s;

    if (frameRateTimer.isFinishedAfterUpdate(delta)) {
        frameRateTimer.restart();
        frameRate = frameRateCount;
        frameRateCount = 1;
    } else frameRateCount += 1;

    sk.fetch.dowork();
    gpu.begin(.{ .a = 1 });
    call(root, "frame", .{delta});
    gpu.end();
    input.endFrame();
}

export fn windowDeinit() void {
    call(root, "deinit", .{});
    sk.gfx.shutdown();
    assets.deinit();
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
pub const isKeyRelease = input.isKeyRelease;
pub const isAnyKeyRelease = input.isAnyKeyRelease;
pub const isButtonRelease = input.isButtonRelease;
pub const initFont = font.init;
