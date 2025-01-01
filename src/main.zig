const std = @import("std");
const System = @import("System.zig");

pub const UNICODE: bool = true;

pub fn main() !void {
    var system = System.initialize();
    defer system.shutdown();

    system.run();
}
