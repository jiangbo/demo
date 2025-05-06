const std = @import("std");
const sk = @import("sokol");
const math = @import("math.zig");
const assets = @import("assets.zig");
const gfx = @import("graphics.zig");

pub const Event = sk.app.Event;
pub const KeyCode = sk.app.Keycode;

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

    pub fn reset(self: *Timer) void {
        self.elapsed = 0;
    }
};

pub var lastKeyState: std.StaticBitSet(512) = .initEmpty();
pub var keyState: std.StaticBitSet(512) = .initEmpty();

pub fn isKeyDown(keyCode: KeyCode) bool {
    return keyState.isSet(@intCast(@intFromEnum(keyCode)));
}

pub fn isAnyKeyDown(keys: []const KeyCode) bool {
    for (keys) |key| if (isKeyDown(key)) return true;
    return false;
}

pub fn isPress(keyCode: KeyCode) bool {
    const key: usize = @intCast(@intFromEnum(keyCode));
    return !lastKeyState.isSet(key) and keyState.isSet(key);
}

pub fn isRelease(keyCode: KeyCode) bool {
    const key: usize = @intCast(@intFromEnum(keyCode));
    return lastKeyState.isSet(key) and !keyState.isSet(key);
}

pub fn showCursor(show: bool) void {
    sk.app.showMouse(show);
}

pub const WindowInfo = struct {
    title: [:0]const u8,
    size: math.Vector,
    alloc: std.mem.Allocator,
    init: ?*const fn () void = null,
    update: ?*const fn (delta: f32) void = null,
    render: ?*const fn () void = null,
    event: ?*const fn (*const Event) void = null,
    deinit: ?*const fn () void = null,
};

pub var size: math.Vector = .zero;
pub var allocator: std.mem.Allocator = undefined;
var timer: std.time.Timer = undefined;
var windowInfo: WindowInfo = undefined;

pub fn run(info: WindowInfo) void {
    timer = std.time.Timer.start() catch unreachable;
    size = info.size;
    allocator = info.alloc;
    windowInfo = info;
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

    sk.gl.setup(.{
        .logger = .{ .func = sk.log.func },
    });

    sk.debugtext.setup(.{
        .fonts = init: {
            var f: [8]sk.debugtext.FontDesc = @splat(.{});
            f[0] = sk.debugtext.fontKc854();
            break :init f;
        },
        .logger = .{ .func = sk.log.func },
    });

    gfx.init(size);

    if (windowInfo.init) |init| init();
    math.setRandomSeed(timer.lap());
}

export fn windowEvent(event: ?*const Event) void {
    if (event) |ev| {
        const code: usize = @intCast(@intFromEnum(ev.key_code));
        switch (ev.type) {
            .KEY_DOWN => keyState.set(code),
            .KEY_UP => keyState.unset(code),
            else => {},
        }
        if (windowInfo.event) |eventHandle| eventHandle(ev);
    }
}

pub fn showFrameRate() void {
    if (frameRateTimer.isRunningAfterUpdate(deltaSeconds)) {
        frameRateCount += 1;
        logicNanoSeconds += timer.read();
    } else {
        frameRateTimer.reset();
        realFrameRate = frameRateCount;
        frameRateCount = 1;
        logicFrameRate = std.time.ns_per_s / logicNanoSeconds * realFrameRate;
        logicNanoSeconds = 0;
    }

    var buffer: [64]u8 = undefined;
    const fmt = std.fmt.bufPrintZ;
    var text = fmt(&buffer, "real frame rate: {d}", .{realFrameRate});
    displayText(2, 2, text catch unreachable);

    text = fmt(&buffer, "logic frame rate: {d}", .{logicFrameRate});
    displayText(2, 4, text catch unreachable);
    endDisplayText();
}

var frameRateTimer: Timer = .init(1);
var frameRateCount: u32 = 0;
var realFrameRate: u32 = 0;
var logicNanoSeconds: u64 = 0;
var logicFrameRate: u64 = 0;
var deltaSeconds: f32 = 0;

export fn windowFrame() void {
    const deltaNano: f32 = @floatFromInt(timer.lap());
    deltaSeconds = deltaNano / std.time.ns_per_s;

    assets.loading();
    if (windowInfo.update) |update| update(deltaSeconds);

    if (windowInfo.render) |render| render();
    lastKeyState = keyState;
}

export fn windowDeinit() void {
    if (windowInfo.deinit) |deinit| deinit();
    sk.gfx.shutdown();
    assets.deinit();
}

pub fn displayText(x: f32, y: f32, text: [:0]const u8) void {
    sk.debugtext.canvas(sk.app.widthf() * 0.4, sk.app.heightf() * 0.4);
    sk.debugtext.origin(x, y);
    sk.debugtext.home();

    sk.debugtext.font(0);
    sk.debugtext.color3b(0xff, 0xff, 0xff);
    sk.debugtext.puts(text);
}

pub fn endDisplayText() void {
    sk.debugtext.draw();
}

pub fn exit() void {
    sk.app.requestQuit();
}
