const std = @import("std");
const chip8 = @import("chip8.zig");

pub fn main() !void {
    var emulator = chip8.Emulator.new();
    emulator.run();
}
