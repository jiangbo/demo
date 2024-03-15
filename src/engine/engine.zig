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

pub fn random(value: usize) usize {
    return randomX(0, value);
}

pub fn randomX(min: usize, max: usize) usize {
    return backend.random(min, max);
}

pub fn shoudContinue() bool {
    return backend.shoudContinue();
}
