const std = @import("std");
const chip8 = @import("chip8.zig");

pub fn main() !void {
    // const rom = @embedFile("roms/1-chip8-logo.ch8");
    const rom = @embedFile("roms/2-ibm-logo.ch8");
    var emulator = chip8.Emulator.new(rom);
    emulator.run();
}
