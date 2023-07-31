const std = @import("std");
const CPU = @import("../cpu.zig").CPU;
const Memory = @import("../memory.zig").Memory;

pub const LDX = struct {
    pub fn execute(self: *LDX, cpu: *CPU, memory: *Memory) void {
        _ = memory;
        _ = cpu;
        _ = self;
        std.log.info("LDX", .{});
    }
};
