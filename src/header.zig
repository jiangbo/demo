const std = @import("std");

const NES = [_]u8{ 0x4E, 0x45, 0x53, 0x1A };
pub const HEADER_LEN = 16;
pub const PRG_LEN: u16 = 0x4000;
pub const CHR_LEN: u16 = 0x2000;

pub const Header = struct {
    header: [HEADER_LEN]u8,
    is_nes: bool = false,
    program: u8 = 0,
    charater: u8 = 0,
    flag6: u8 = 0,
    flag7: u8 = 0,

    pub fn decode(self: *Header) void {
        self.is_nes = std.mem.eql(u8, &NES, self.header[0..4]);
        self.program = self.header[4];
        self.charater = self.header[5];
        self.flag6 = self.header[6];
        self.flag7 = self.header[7];
    }

    pub fn programLength(self: *Header) u16 {
        return self.program * PRG_LEN;
    }
};

pub var header: Header = undefined;

pub fn init(rom: []const u8) *Header {
    header = Header{ .header = undefined };
    @memcpy(&header.header, rom[0..HEADER_LEN]);
    header.decode();
    return &header;
}
