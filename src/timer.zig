const std = @import("std");
const win32 = @import("win32");

pub const Timer = struct {
    elapsed: f32 = 0.0,
    total: f32 = 0.0,
    start: f32 = 0,
    frequency: f32 = 0.0,

    pub fn init() Timer {
        var timer: Timer = undefined;

        var i: win32.foundation.LARGE_INTEGER = undefined;

        _ = win32.system.performance.QueryPerformanceFrequency(&i);
        timer.frequency = @floatFromInt(i.QuadPart);

        _ = win32.system.performance.QueryPerformanceCounter(&i);
        timer.start = @floatFromInt(i.QuadPart);
        return timer;
    }

    pub fn update(self: *Timer) void {
        var i: win32.foundation.LARGE_INTEGER = undefined;
        _ = win32.system.performance.QueryPerformanceCounter(&i);
        const current: f32 = @floatFromInt(i.QuadPart);
        self.elapsed = (current - self.start) / self.frequency;
        self.total += self.elapsed;
        self.start = current;
    }
};
