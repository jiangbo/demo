const std = @import("std");

const Memory = @import("memory.zig").Memory;
const CPU = @import("cpu.zig").CPU;

const jmp = @import("opcode/jmp.zig");

pub const Opcode = enum(u8) {
    JMP = 0x4C,
    LDX = 0xA2,
    _,
};

pub const Instruct = struct {
    opcode: u8,
    type: Opcode = undefined,
    data1: ?u8 = null,
    data2: ?u8 = null,

    pub fn decode(self: *Instruct) void {
        if (std.meta.intToEnum(Opcode, self.opcode)) |opcode| {
            self.type = opcode;
        } else |e| {
            std.log.info("instruct decode error: {}", .{e});
        }
    }

    pub fn execute(self: *Instruct, cpu: *CPU, memory: *Memory) void {
        switch (self.type) {
            .JMP => {
                self.data1 = memory.get(cpu.pc + 1);
                self.data2 = memory.get(cpu.pc + 2);
                self.print(cpu, memory);
                cpu.pc = self.address();
            },
            else => {
                std.log.info("unkonwn opcode: {}", .{self.opcode});
            },
        }
    }

    pub fn address(self: *Instruct) u16 {
        return (@as(u16, self.data2.?) << 8) | self.data1.?;
    }

    pub fn print(self: *Instruct, cpu: *CPU, memory: *Memory) void {
        _ = memory;
        // std.log.info("{X:0>4}  {X:0>2}  ", .{ cpu.pc, self.opcode });
        std.debug.print("{X:0>4}  {X:0>2}  ", .{ cpu.pc, self.opcode });
    }
};

// pub const Instruct = union(Opcode) {
//     JMP: jmp.JMP,

//     pub fn execute(self: Instruct) void {
//         switch (self) {
//             inline else => |case| case.execute(),
//         }
//     }
// };
