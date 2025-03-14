const std = @import("std");
const sk = @import("sokol");

pub const Event = sk.app.Event;
pub const CallbackInfo = struct {
    title: [:0]const u8,
    init: ?*const fn () void = null,
    update: ?*const fn () void = null,
    render: ?*const fn () void = null,
    event: ?*const fn (*const Event) void = null,
    deinit: ?*const fn () void = null,
};

pub var width: f32 = 1280;
pub var height: f32 = 720;

var timer: std.time.Timer = undefined;
var deltaTime: f32 = 0;
var totalTime: f32 = 0;
pub fn deltaMillisecond() f32 {
    return deltaTime;
}

pub fn totalMillisecond() f32 {
    return totalTime;
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
    sk.app.quit();
}

var callback: CallbackInfo = undefined;
pub fn run(info: CallbackInfo) void {
    callback = info;
    sk.app.run(.{
        .width = @as(i32, @intFromFloat(width)),
        .height = @as(i32, @intFromFloat(height)),
        .window_title = info.title,
        .logger = .{ .func = sk.log.func },
        .win32_console_attach = true,
        .init_cb = if (info.init) |_| init else null,
        .event_cb = if (info.event) |_| event else null,
        .frame_cb = if (info.update != null or info.render != null) frame else null,
        .cleanup_cb = if (info.deinit) |_| cleanup else null,
    });
}

export fn init() void {
    sk.gfx.setup(.{
        .environment = sk.glue.environment(),
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

    timer = std.time.Timer.start() catch unreachable;
    callback.init.?();
}

export fn event(evt: ?*const Event) void {
    if (evt) |e| callback.event.?(e);
}

export fn frame() void {
    const nano: f32 = @floatFromInt(timer.lap());
    deltaTime = nano / std.time.ns_per_ms;
    totalTime += deltaTime;
    callback.render.?();
    callback.update.?();
}

export fn cleanup() void {
    sk.gfx.shutdown();
    callback.deinit.?();
}
