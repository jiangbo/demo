const std = @import("std");
const Header = @import("header.zig").Header;

const nes = @import("nes.zig");

pub fn main() !void {
    var emulator: nes.Emulator = undefined;
    {
        const rom = @embedFile("roms/nestest.nes");
        emulator = nes.Emulator.new(rom);
    }
    emulator.run();
}
