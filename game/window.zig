const std = @import("std");
const sk = @import("sokol");

const context = @import("context.zig");

pub const Event = sk.app.Event;
pub const RunInfo = struct {
    init: *const fn () void,
    frame: *const fn () void,
    event: *const fn (?*const Event) void,
    deinit: *const fn () void,
};

pub fn deltaMillisecond() f32 {
    return @floatCast(sk.app.frameDuration() * 1000);
}

var runInfo: RunInfo = undefined;
pub fn run(info: RunInfo) void {
    runInfo = info;
    sk.app.run(.{
        .width = @as(i32, @intFromFloat(context.width)),
        .height = @as(i32, @intFromFloat(context.height)),
        .window_title = context.title,
        .logger = .{ .func = sk.log.func },
        .win32_console_attach = true,
        .init_cb = init,
        .event_cb = event,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
    });
}

export fn init() void {
    sk.gfx.setup(.{
        .environment = sk.glue.environment(),
        .logger = .{ .func = sk.log.func },
    });
    runInfo.init();
}

export fn event(evt: ?*const Event) void {
    runInfo.event(evt);
}

export fn frame() void {
    runInfo.frame();
}

export fn cleanup() void {
    sk.gfx.shutdown();
    runInfo.deinit();
}
