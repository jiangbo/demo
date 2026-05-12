const std = @import("std");

pub fn init() void {
    std.log.info("spawn init", .{});
}

pub fn deinit() void {}
