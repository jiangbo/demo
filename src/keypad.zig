const c = @cImport(@cInclude("SDL.h"));
const std = @import("std");

pub const Keypad = struct {
    buffer: [16]bool = undefined,

    pub fn new() Keypad {
        return Keypad{
            .buffer = std.mem.zeroes([16]bool),
        };
    }

    pub fn poll(self: *Keypad) bool {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) > 0) {
            if (event.type == c.SDL_QUIT) return false;

            const flag = if (event.type == c.SDL_KEYDOWN) true //
            else if (event.type == c.SDL_KEYUP) false //
            else return true;
            self.setBuffer(event.key.keysym.sym, flag);
        }
        return true;
    }

    fn setBuffer(self: *Keypad, code: i32, value: bool) void {
        var buffer = switch (code) {
            c.SDLK_x => &self.buffer[0],
            c.SDLK_1 => &self.buffer[1],
            c.SDLK_2 => &self.buffer[2],
            c.SDLK_3 => &self.buffer[3],
            c.SDLK_q => &self.buffer[4],
            c.SDLK_w => &self.buffer[5],
            c.SDLK_e => &self.buffer[6],
            c.SDLK_a => &self.buffer[7],
            c.SDLK_s => &self.buffer[8],
            c.SDLK_d => &self.buffer[9],
            c.SDLK_z => &self.buffer[10],
            c.SDLK_c => &self.buffer[11],
            c.SDLK_4 => &self.buffer[12],
            c.SDLK_r => &self.buffer[13],
            c.SDLK_f => &self.buffer[14],
            c.SDLK_v => &self.buffer[15],
            else => return,
        };
        buffer.* = value;
    }
};
