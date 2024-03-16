const std = @import("std");
const backend = @import("backend.zig");

const Alloc = std.mem.Allocator;
pub var allocator: std.mem.Allocator = undefined;
pub fn init(a: Alloc, width: usize, height: usize, title: [:0]const u8) void {
    allocator = a;
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
    return randomW(0, value);
}

pub fn randomW(min: usize, max: usize) usize {
    return backend.random(min, max);
}

pub fn shoudContinue() bool {
    return backend.shoudContinue();
}
