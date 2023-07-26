const std = @import("std");
const Instruct = @import("instruct.zig").Instruct;
const Memory = @import("memory.zig").Memory;

pub const CPU = struct {
    instruct: Instruct = undefined,
    register: [16]u8 = std.mem.zeroes([16]u8),
    index: u16 = 0,
    pc: u16,

    pub fn cycle(self: *CPU, memory: *Memory) void {
        self.fetch(memory);
        self.decode();
        self.execute(memory);
    }

    fn fetch(self: *CPU, memory: *Memory) void {
        var opcode = memory.load(self.pc);
        self.instruct = Instruct{ .opcode = opcode };
        self.next();
    }

    fn next(self: *CPU) void {
        self.pc += 2;
    }

    fn decode(self: *CPU) void {
        self.instruct.decode();
    }

    fn execute(self: *CPU, memory: *Memory) void {
        const ins = &self.instruct;
        var reg = &self.register;
        switch (ins.code) {
            0x0 => memory.clearScreen(),
            0x1 => self.pc = ins.nnn,
            0x6 => reg[ins.x] = ins.nn,
            0x7 => reg[ins.x] +%= ins.nn,
            0xA => self.index = ins.nnn,
            0xD => self.draw(memory),
            else => std.log.info("unknown opcode: 0x{X:0>4}", .{ins.opcode}),
        }
    }

    const width: u8 = 0x80;
    fn draw(self: *CPU, memory: *Memory) void {
        self.register[0xF] = 0;
        var rx = self.register[self.instruct.x];
        var ry = self.register[self.instruct.y];
        for (0..self.instruct.n) |row| {
            const sprite = memory.ram[self.index + row];
            for (0..8) |col| {
                const shift = width >> @as(u3, @truncate(col));
                if (sprite & shift == 0) continue;
                if (!memory.setPixel(rx + col, ry + row)) {
                    self.register[0xF] = 1;
                }
            }
        }
    }
};
