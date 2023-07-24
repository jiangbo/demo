const std = @import("std");
const chip8 = @import("chip8.zig");

pub fn main() !void {
    // const rom = @embedFile("IBM Logo.ch8");
    // const rom = @embedFile("test_opcode.ch8");
    // const rom = @embedFile("1-chip8-logo.ch8");
    // const rom = @embedFile("2-ibm-logo.ch8");
    // const rom = @embedFile("3-corax+.ch8");
    const rom = @embedFile("4-flags.ch8");
    var emulator = chip8.Emulator.new(rom);
    emulator.run();
}
