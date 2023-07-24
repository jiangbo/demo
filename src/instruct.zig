const c = @cImport(@cInclude("SDL.h"));
const std = @import("std");

pub const Instruct = struct {
    opcode: u16,
    x: u8 = undefined,
    y: u8 = undefined,
    nnn: u16 = undefined,
    kk: u8 = undefined,

    pub fn decode(self: *Instruct) void {
        self.x = @as(u8, @intCast((self.opcode & 0x0F00) >> 8));
        self.y = @as(u8, @intCast((self.opcode & 0x00F0) >> 4));
        self.nnn = self.opcode & 0x0FFF;
        self.kk = @as(u8, @intCast(self.opcode & 0x00FF));
    }
};
