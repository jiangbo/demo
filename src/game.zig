const std = @import("std");
const Screen = @import("screen.zig").Screen;
const Tetrimino = @import("block.zig").Tetrimino;

pub const Game = struct {
    current: Tetrimino,

    pub fn new() Game {
        return Game{ .current = Tetrimino.random() };
    }

    // pub fn update(self: *Game) void {
    //     _ = self;
    // }

    pub fn draw(self: *Game, screen: *Screen) void {
        drawTetrimino(&self.current, screen);
        screen.drawEmpty(4, 2);
    }

    pub fn drawTetrimino(block: *Tetrimino, screen: *Screen) void {
        const value = block.position();
        var index: usize = 0;
        while (index < value.len) : (index += 2) {
            const x = block.x + value[index];
            const y = block.y + value[index + 1];
            screen.draw(x, y, block.color);
        }
    }
};
