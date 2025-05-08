const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");

pub fn init() void {
    std.log.info("init title", .{});
}

pub fn update(delta: f32) void {
    std.log.info("update title", .{});
    _ = delta;
}

pub fn render() void {
    std.log.info("render title", .{});
}
