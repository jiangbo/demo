const std = @import("std");
const instruct = @import("instruct.zig");
const Memory = @import("memory.zig").Memory;

pub const CPU = struct {
    pc: u16 = 0,
    instruct: instruct.Instruct = undefined,

    pub fn cycle(self: *CPU, memory: *Memory) void {
        self.fetch(memory);
        self.decode();
        self.execute(memory);
    }

    fn fetch(self: *CPU, memory: *Memory) void {
        const opcode = memory.get(self.pc);
        self.instruct = instruct.Instruct{ .opcode = opcode };
    }

    fn decode(self: *CPU) void {
        self.instruct.decode();
    }

    fn execute(self: *CPU, memory: *Memory) void {
        self.instruct.execute(self, memory);
    }
};
