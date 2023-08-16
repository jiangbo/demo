const std = @import("std");
const c = @import("c.zig");
const screen = @import("screen.zig");
const game = @import("game.zig");

const FPS = 60;
const WIDTH: usize = 10;
const HEIGHT: usize = 20;

pub const Tetris = struct {
    game: game.Game,
    screen: screen.Screen,

    pub fn new() Tetris {
        return Tetris{
            .game = game.Game.new(WIDTH, HEIGHT),
            .screen = screen.Screen{ .width = WIDTH, .height = HEIGHT },
        };
    }

    pub fn run(self: *Tetris) void {
        self.screen.init();
        defer self.screen.deinit();

        mainLoop: while (true) {
            var event: c.SDL_Event = undefined;
            while (c.SDL_PollEvent(&event) != 0) {
                if (event.type == c.SDL_QUIT)
                    break :mainLoop;
                self.handleInput(&event);
            }

            self.screen.clear();
            self.game.draw(&self.screen);
            self.screen.present(FPS);
        }
    }

    fn handleInput(self: *Tetris, event: *c.SDL_Event) void {
        if (event.type != c.SDL_KEYDOWN) return;

        const code = event.key.keysym.sym;
        switch (code) {
            c.SDLK_LEFT => self.game.move(-1, 0),
            c.SDLK_RIGHT => self.game.move(1, 0),
            c.SDLK_UP => self.game.rotate(),
            c.SDLK_DOWN => self.game.move(0, 1),
            c.SDLK_SPACE => self.game.rotate(),
            else => return,
        }
    }
};
