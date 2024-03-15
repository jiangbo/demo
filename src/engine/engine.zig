const std = @import("std");
const backend = @import("backend.zig");

pub fn init(width: usize, height: usize, title: [:0]const u8) void {
    backend.init(width, height, title);
}

pub fn deinit() void {
    backend.deinit();
}

pub fn beginDraw() void {
    backend.beginDraw();
}

pub fn endDraw() void {
    backend.endDraw();
}

pub fn getPressed() usize {
    return backend.getPressed();
}

pub fn isPressed(key: usize) bool {
    return backend.isPressed(key);
}

pub fn time() usize {
    return backend.time();
}

pub fn shoudContinue() bool {
    return backend.shoudContinue();
}
