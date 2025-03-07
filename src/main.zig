const std = @import("std");
const window = @import("window.zig");

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    window.width = 1280;
    window.height = 720;

    window.run(.{ .title = "植物明星大乱斗" });
}
