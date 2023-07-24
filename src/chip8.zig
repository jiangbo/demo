const c = @cImport(@cInclude("SDL.h"));
const std = @import("std");
const cpu = @import("cpu.zig");
const mem = @import("memory.zig");
const screen = @import("screen.zig");
const keypad = @import("keypad.zig");

const ENTRY = 0x200;

pub const Emulator = struct {
    cpu: cpu.CPU,
    memory: mem.Memory,
    screen: screen.Screen,
    keypad: keypad.Keypad,

    pub fn new(rom: []const u8) Emulator {
        const seed = @as(u64, @intCast(std.time.timestamp()));
        var prng = std.rand.DefaultPrng.init(seed);
        return Emulator{
            .cpu = cpu.CPU{ .pc = ENTRY, .prng = prng },
            .memory = mem.Memory.new(rom, ENTRY),
            .screen = screen.Screen.new(),
            .keypad = keypad.Keypad.new(),
        };
    }

    pub fn run(self: *Emulator) void {
        self.memory.screen = &self.screen;
        self.screen.init();
        defer self.screen.deinit();

        mainloop: while (true) {
            self.cpu.cycle(&self.memory);
            while (self.keypad.pollEvent()) |event| {
                if (event.type == c.SDL_QUIT)
                    break :mainloop;
            }
            self.screen.update();
            c.SDL_Delay(100);
        }
    }
};
