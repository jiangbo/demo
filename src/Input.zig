const std = @import("std");
const win32 = @import("win32");

keys: [256]bool,

pub fn initialize() @This() {
    return .{ .keys = .{false} ** 256 };
}

pub fn keyDown(self: *@This(), input: usize) void {
    self.keys[input] = true;
}

pub fn keyUp(self: *@This(), input: usize) void {
    self.keys[input] = false;
}

pub fn isKeyDown(self: *@This(), input: u32) bool {
    return self.keys[input];
}
