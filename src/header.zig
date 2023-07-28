const std = @import("std");

const nes = [_]u8{ 0x4E, 0x45, 0x53, 0x1A };

pub const Header = struct {
    header: []const u8,
    is_nes: bool = false,
    program: u8 = 0,
    charater: u8 = 0,
    flag6: u8 = 0,
    flag7: u8 = 0,

    pub fn init(rom: []const u8) Header {
        return Header{ .header = rom[0..16] };
    }

    pub fn decode(self: *Header) void {
        self.is_nes = std.mem.eql(u8, &nes, self.header[0..4]);
        self.program = self.header[4];
        self.charater = self.header[5];
        self.flag6 = self.header[6];
        self.flag7 = self.header[7];
    }
};
