const std = @import("std");
const sk = @import("sokol");
const math = @import("math.zig");
const assets = @import("assets.zig");
const gfx = @import("graphics.zig");
const audio = @import("audio.zig");
const input = @import("input.zig");

pub const Event = sk.app.Event;

pub const Char = struct {
    id: u32,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    xOffset: f32,
    yOffset: f32,
    xAdvance: f32,
    page: u8,
    chnl: u8,
};

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
    chars: []const Char = &.{},
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

    if (info.chars.len != 0) {
        const len: u32 = @intCast(info.chars.len);
        fonts.ensureTotalCapacity(alloc, len) catch unreachable;
    }
    for (info.chars) |char| {
        fonts.putAssumeCapacity(char.id, char);
    }

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

    math.setRandomSeed(timer.lap());
    call(root, "init", .{});
}

pub var fonts: std.AutoHashMapUnmanaged(u32, Char) = .empty;
pub var lineHeight: f32 = 0;
pub var fontTexture: gfx.Texture = undefined;
pub var mousePosition: math.Vector = .zero;

export fn windowEvent(event: ?*const Event) void {
    if (event) |ev| {
        input.event(ev);
        const ratio = size.div(.init(sk.app.widthf(), sk.app.heightf()));
        mousePosition = input.mousePosition.mul(ratio);
        call(root, "event", .{ev});
    }
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
    call(root, "frame", .{delta});
    input.endFrame();
}

export fn windowDeinit() void {
    call(root, "deinit", .{});
    fonts.deinit(allocator);
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
pub const isAnyKeyRelease = input.isAnyKeyRelease;
pub const isButtonRelease = input.isButtonRelease;
