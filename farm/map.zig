const std = @import("std");

pub fn init() void {
    std.log.info("map init", .{});
}

pub fn deinit() void {}
