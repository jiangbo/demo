const c = @cImport(@cInclude("SDL.h"));
const std = @import("std");
const cpu = @import("cpu.zig");
const mem = @import("mem.zig");
const screen = @import("screen.zig");
const keypad = @import("keypad.zig");

pub const Emulator = struct {
    cpu: cpu.CPU,
    memory: mem.Memory,
    screen: screen.Screen,
    keypad: keypad.Keypad,

    pub fn new() Emulator {
        return Emulator{
            .cpu = cpu.CPU{},
            .memory = mem.Memory.new(),
            .screen = screen.Screen.new(),
            .keypad = keypad.Keypad.new(),
        };
    }

    pub fn run(self: *Emulator) void {
        self.screen.init();
        defer self.screen.deinit();

        mainloop: while (true) {
            self.cpu.cycle();
            while (self.keypad.pollEvent()) |event| {
                if (event.type == c.SDL_QUIT)
                    break :mainloop;
            }
            c.SDL_Delay(30);
        }
    }
};
