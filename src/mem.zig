const std = @import("std");
const screen = @import("screen.zig");

pub const Memory = struct {
    ram: [4096]u8 = undefined,
    stack: [16]u16 = undefined,
    sp: u8 = 0,
    screen: *screen.Screen = undefined,

    pub fn new(rom: []const u8, entry: u16) Memory {
        var memory = Memory{};
        @memcpy(memory.ram[0..fonts.len], &fonts);
        @memcpy(memory.ram[entry .. entry + rom.len], rom);
        return memory;
    }

    pub fn load(self: *Memory, pc: u16) u16 {
        const high: u8 = self.ram[pc];
        return (@as(u16, high) << 8) | self.ram[pc + 1];
        // return std.mem.readIntSliceBig(u16, self.ram[pc .. pc + 1]);
    }

    pub fn clearScreen(self: *Memory) void {
        var screen1 = self.screen;
        screen1.clear();
    }

    pub fn setPixel(self: *Memory, x: usize, y: usize) bool {
        return self.screen.setPixel(x, y);
    }

    fn push(self: *Memory, value: u16) void {
        self.stack[self.sp] = value;
        self.sp += 1;
    }

    fn pop(self: *Memory) u16 {
        defer self.sp -= 1;
        return self.stack[self.sp];
    }
};

const fonts = [_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xe0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};
