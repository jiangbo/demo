const std = @import("std");
const head = @import("header.zig");
const cpu = @import("cpu.zig");
const memory = @import("memory.zig");

pub const Emulator = struct {
    cpu: cpu.CPU,
    memory: memory.Memory,

    pub fn new(rom: []const u8) Emulator {
        const header = head.init(rom);
        const mem = memory.Memory.new(rom[head.HEADER_LEN..], header);
        return Emulator{
            .cpu = cpu.CPU{ .pc = 0xC000 },
            .memory = mem,
        };
    }

    pub fn run(self: *Emulator) void {
        self.cpu.cycle(&self.memory);
    }
};
