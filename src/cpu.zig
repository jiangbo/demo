const std = @import("std");
const Memory = @import("memory.zig").Memory;

pub const CPU = struct {
    pub fn cycle(self: *CPU, memory: *Memory) void {
        self.fetch(memory);
        self.decode();
        self.execute(memory);
    }

    fn fetch(self: *CPU, memory: *Memory) void {
        _ = memory;
        _ = self;
    }

    fn decode(self: *CPU) void {
        _ = self;
    }

    fn execute(self: *CPU, memory: *Memory) void {
        _ = memory;
        _ = self;
    }
};
