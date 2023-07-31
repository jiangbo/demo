const std = @import("std");
const header = @import("header.zig");

const START: u16 = 0x8000;

pub const Memory = struct {
    ram: [64 * 1024]u8 = undefined,

    pub fn new(rom: []const u8, head: *header.Header) Memory {
        var memory = Memory{};
        const len: u32 = head.programLength();
        const program = rom[0..len];
        if (head.program == 1) {
            @memcpy(memory.ram[START .. START + len], program);
            @memcpy(memory.ram[START + len .. START + len + len], program);
        } else {
            @memcpy(memory.ram[START .. START + len], program);
        }
        return memory;
    }

    pub fn load(self: *Memory, addr: u16) u16 {
        const high: u8 = self.ram[addr + 1];
        return (@as(u16, high) << 8) | self.ram[addr];
    }

    pub fn get(self: *Memory, index: u16) u8 {
        return self.ram[index];
    }
};
