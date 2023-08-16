const std = @import("std");
const Screen = @import("screen.zig").Screen;
const Tetrimino = @import("block.zig").Tetrimino;

pub const Game = struct {
    width: i32,
    height: i32,
    current: Tetrimino,
    prng: std.rand.DefaultPrng,
    pub fn new(width: usize, height: usize) Game {
        const seed = @as(u64, @intCast(std.time.timestamp()));
        var rand = std.rand.DefaultPrng.init(seed);
        return Game{
            .width = @intCast(width),
            .height = @intCast(height),
            .current = Tetrimino.random(&rand),
            .prng = rand,
        };
    }

    // pub fn update(self: *Game) void {
    //     _ = self;
    // }

    pub fn draw(self: *Game, screen: *Screen) void {
        drawTetrimino(&self.current, screen);
    }

    pub fn drawTetrimino(block: *Tetrimino, screen: *Screen) void {
        const value = block.position();
        var index: usize = 0;
        while (index < value.len) : (index += 2) {
            const x: usize = @intCast(block.x + value[index]);
            const y: usize = @intCast(block.y + value[index + 1]);
            screen.draw(x, y, block.color);
        }
    }

    pub fn move(self: *Game, x: i8, y: i8) void {
        self.current.x = self.current.x + x;
        self.current.y = self.current.y + y;

        self.current.locateIn(self.width, self.height);
    }

    pub fn rotate(self: *Game) void {
        self.current.rotate();
        self.current.locateIn(self.width, self.height);
    }
};
