const std = @import("std");

const context = @import("context.zig");

pub const DispatchMode = enum {
    immediate,
    queued,
};

pub const Event = union(enum) {
    scene_request: context.Scene,
    debug_note: [:0]const u8,
};

pub const TraceEntry = struct {
    mode: DispatchMode,
    event: Event,
};

const max_queue = 64;
const max_trace = 32;

var queue: [max_queue]Event = undefined;
var queue_len: usize = 0;

var trace: [max_trace]TraceEntry = undefined;
var trace_len: usize = 0;

pub fn init() void {
    queue_len = 0;
    trace_len = 0;
}

pub fn deinit() void {
    queue_len = 0;
    trace_len = 0;
}

pub fn trigger(value: Event) void {
    handle(value, .immediate);
}

pub fn enqueue(value: Event) void {
    if (queue_len >= queue.len) {
        record(.{
            .mode = .immediate,
            .event = .{ .debug_note = "event queue full" },
        });
        return;
    }

    queue[queue_len] = value;
    queue_len += 1;
}

pub fn update() void {
    var i: usize = 0;
    while (i < queue_len) : (i += 1) {
        handle(queue[i], .queued);
    }
    queue_len = 0;
}

pub fn recentTrace() []const TraceEntry {
    return trace[0..trace_len];
}

pub fn clearTrace() void {
    trace_len = 0;
}

pub fn eventName(value: Event) [:0]const u8 {
    return switch (value) {
        .scene_request => "scene_request",
        .debug_note => "debug_note",
    };
}

pub fn modeName(mode: DispatchMode) [:0]const u8 {
    return switch (mode) {
        .immediate => "Immediate",
        .queued => "Queued",
    };
}

fn handle(value: Event, mode: DispatchMode) void {
    switch (value) {
        .scene_request => |scene| context.requestScene(scene),
        .debug_note => {},
    }

    record(.{ .mode = mode, .event = value });
}

fn record(entry: TraceEntry) void {
    if (trace_len < trace.len) {
        trace[trace_len] = entry;
        trace_len += 1;
        return;
    }

    std.mem.copyForwards(TraceEntry, trace[0..trace.len - 1], trace[1..]);
    trace[trace.len - 1] = entry;
}

test "trigger handles scene request immediately" {
    context.init();
    init();

    trigger(.{ .scene_request = .farm });

    try std.testing.expectEqual(context.Scene.farm, context.pendingScene.?);
    try std.testing.expectEqual(@as(usize, 1), recentTrace().len);
    try std.testing.expectEqual(DispatchMode.immediate, recentTrace()[0].mode);
}

test "enqueue waits for update" {
    context.init();
    init();

    enqueue(.{ .scene_request = .farm });

    try std.testing.expectEqual(@as(?context.Scene, null), context.pendingScene);

    update();

    try std.testing.expectEqual(context.Scene.farm, context.pendingScene.?);
    try std.testing.expectEqual(@as(usize, 1), recentTrace().len);
    try std.testing.expectEqual(DispatchMode.queued, recentTrace()[0].mode);
}
