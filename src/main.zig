const std = @import("std");
const chip8 = @import("chip8.zig");

pub fn main() !void {
    // const rom = @embedFile("IBM Logo.ch8");
    // const rom = @embedFile("test_opcode.ch8");
    // const rom = @embedFile("BC_test.ch8");
    // const rom = @embedFile("1-chip8-logo.ch8");
    // const rom = @embedFile("2-ibm-logo.ch8");
    // const rom = @embedFile("3-corax+.ch8");
    // const rom = @embedFile("4-flags.ch8");
    // const rom = @embedFile("5-quirks.ch8");
    // const rom = @embedFile("6-keypad.ch8");
    // const rom = @embedFile("Tetris [Fran Dachille, 1991].ch8");
    const rom = @embedFile("tetris.rom");
    var emulator = chip8.Emulator.new(rom);
    emulator.run();
}
// const std = @import("std");

// pub fn main() !void {
//     const a: u8 = 95;
//     const b: u8 = 100;
//     const res = @subWithOverflow(a, b);
//     std.log.info("res: {}, ov: {}", .{ res.@"0", res.@"1" });
// }
