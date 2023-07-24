const std = @import("std");
const mem = @import("mem.zig");
const instruct = @import("instruct.zig");

pub const CPU = struct {
    instruct: instruct.Instruct = undefined,
    register: [16]u8 = std.mem.zeroes([16]u8),
    index: u16 = 0,
    pc: u16,
    delay: u8 = 0,
    sound: u8 = 0,

    pub fn cycle(self: *CPU, memory: *mem.Memory) void {
        self.fetch(memory);
        self.decode();
        self.execute(memory);
    }

    fn fetch(self: *CPU, memory: *mem.Memory) void {
        var opcode = memory.load(self.pc);
        std.log.info("opcode: 0x{X:0>4}", .{opcode});
        self.instruct = instruct.Instruct{ .opcode = opcode };
        self.pc += 2;
    }

    fn decode(self: *CPU) void {
        self.instruct.decode();
    }

    fn execute(self: *CPU, memory: *mem.Memory) void {
        const ins = self.instruct;
        switch (ins.opcode) {
            0x00E0 => memory.clearScreen(),
            0x1000...0x1FFF => self.pc = ins.nnn,
            0x6000...0x6FFF => self.register[ins.x] = ins.kk,
            0x7000...0x7FFF => self.register[ins.x] +%= ins.kk,
            0xA000...0xAFFF => self.index = self.instruct.nnn,
            0xD000...0xDFFF => self.draw(memory),
            else => |v| std.log.info("unknow opcode: 0x{X:0>4}", .{v}),
        }
    }

    const width: u8 = 0x80; // 每个精灵的固定宽度
    fn draw(self: *CPU, memory: *mem.Memory) void {
        self.register[0xF] = 0;
        var rx = self.register[self.instruct.x];
        var ry = self.register[self.instruct.y];
        for (0..self.instruct.n) |row| {
            const sprite = memory.ram[self.index + row];
            for (0..8) |col| {
                const shift = width >> @as(u3, @truncate(col));
                if (sprite & shift == 0) continue;
                if (memory.setPixel(rx + col, ry + row)) {
                    self.register[0xF] = 1;
                }
            }
        }
    }
};
