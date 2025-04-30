const std = @import("std");
const sk = @import("sokol");
const math = @import("math.zig");

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

    pub fn reset(self: *Timer) void {
        self.elapsed = 0;
    }
};

pub var size: math.Vector = .zero;
var keyState: std.StaticBitSet(512) = .initEmpty();

pub fn event(ev: *const Event) void {
    switch (ev.type) {
        .KEY_DOWN => keyState.set(@intCast(@intFromEnum(ev.key_code))),
        .KEY_UP => keyState.unset(@intCast(@intFromEnum(ev.key_code))),
        else => {},
    }
}

pub fn isKeyDown(keyCode: KeyCode) bool {
    return keyState.isSet(@intCast(@intFromEnum(keyCode)));
}

pub fn showCursor(show: bool) void {
    sk.app.showMouse(show);
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
pub const run = sk.app.run;
pub const KeyCode = sk.app.Keycode;
pub const log = sk.log.func;
