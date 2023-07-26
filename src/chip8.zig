const cpu = @import("cpu.zig");
const memory = @import("memory.zig");
const screen = @import("screen.zig");
const keypad = @import("keypad.zig");

const HZ = 500;
const FPS = 60;

pub const Emulator = struct {
    cpu: cpu.CPU,
    memory: memory.Memory,
    screen: screen.Screen,
    keypad: keypad.Keypad,

    pub fn new() Emulator {
        return Emulator{
            .cpu = cpu.CPU{},
            .memory = memory.Memory{},
            .screen = screen.Screen{},
            .keypad = keypad.Keypad{},
        };
    }

    pub fn run(self: *Emulator) void {
        self.screen.init();
        defer self.screen.deinit();

        var index: usize = 0;
        while (self.keypad.poll()) : (index += 1) {
            for (0..(HZ / FPS)) |_|
                self.cpu.cycle(&self.memory);

            if (index % 44 == 0) self.screen.clear();
            _ = self.screen.setIndex(index);
            self.screen.update(FPS);
        }
    }
};
