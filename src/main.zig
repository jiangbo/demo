const std = @import("std");
const Header = @import("header.zig").Header;

pub fn main() !void {
    const rom = @embedFile("roms/nestest.nes");
    std.log.info("", .{});

    var header = Header.init(rom);
    header.decode();
    std.log.info("is nes file: {}", .{header.is_nes});

    std.log.info("program length: {}", .{header.program});
    std.log.info("charater length: {}", .{header.charater});
}
