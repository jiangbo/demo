const std = @import("std");
const c = @import("c.zig");
const screen = @import("screen.zig");
const game = @import("game.zig");
// const keypad = @import("keypad.zig");

pub const Tetris = struct {
    game: game.Game,
    screen: screen.Screen,
    // keypad: keypad.Keypad,

    pub fn new() Tetris {
        return Tetris{
            .game = game.Game.new(),
            .screen = screen.Screen{},
            // .keypad: keypad

        };
    }

    pub fn run(self: *Tetris) void {
        self.screen.init();
        defer self.screen.deinit();

        mainLoop: while (true) {
            const start = c.SDL_GetTicks();
            var event: c.SDL_Event = undefined;
            while (c.SDL_PollEvent(&event) != 0) {
                if (event.type == c.SDL_QUIT)
                    break :mainLoop;
            }

            self.screen.clear();
            self.game.draw(&self.screen);
            self.screen.present();
            const current = c.SDL_GetTicks();
            const delta = current - start;
            _ = delta;
        }
    }
};
