const std = @import("std");
const chip8 = @import("chip8.zig");

pub fn main() !void {
    const rom = @embedFile("IBM Logo.ch8");
    var emulator = chip8.Emulator.new(rom);
    emulator.run();
}
