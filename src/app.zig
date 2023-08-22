const std = @import("std");
const Screen = @import("display.zig").Screen;
const Tetrimino = @import("block.zig").Tetrimino;

pub const Game = struct {
    current: Tetrimino,
    prng: std.rand.DefaultPrng,

    pub fn new() Game {
        const seed = @as(u64, @intCast(std.time.timestamp()));
        var rand = std.rand.DefaultPrng.init(seed);
        return Game{
            .current = Tetrimino.random(&rand),
            .prng = rand,
        };
    }

    pub fn drawCurrent(self: *Game, screen: *Screen) void {
        draw(&self.current, screen);
    }

    pub fn moveLeft(self: *Game, screen: *Screen) void {
        _ = screen;
        self.move(-1, 0);
    }

    pub fn moveRight(self: *Game, screen: *Screen) void {
        _ = screen;
        self.move(1, 0);
    }

    pub fn moveDown(self: *Game, screen: *Screen) void {
        _ = screen;
        self.move(0, 1);
    }

    fn move(self: *Game, x: i8, y: i8) void {
        self.current.x = self.current.x + x;
        self.current.y = self.current.y + y;
        self.current.locateIn();
    }

    pub fn rotate(self: *Game, screen: *Screen) void {
        _ = screen;
        self.current.rotate();
        self.current.locateIn();
    }
};

fn draw(block: *const Tetrimino, screen: *Screen) void {
    const value = block.position();
    var index: usize = 0;
    while (index < value.len) : (index += 2) {
        const row: usize = @intCast(block.x + value[index]);
        const col: usize = @intCast(block.y + value[index + 1]);
        screen.draw(row, col, block.color);
    }
}
