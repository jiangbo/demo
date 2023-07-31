const std = @import("std");
const CPU = @import("../cpu.zig").CPU;
const Memory = @import("../memory.zig").Memory;

pub const JMP = struct {
    pub fn execute(self: JMP, cpu: *CPU, memory: *Memory) void {
        _ = memory;
        _ = cpu;
        _ = self;
        std.log.info("JMP ", .{});
        //  std.log.info("{X:0>4}  {X:0>2}", .{ self.pc, opcode });
    }
};
