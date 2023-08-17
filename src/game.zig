const std = @import("std");
const Screen = @import("screen.zig").Screen;
const Tetrimino = @import("block.zig").Tetrimino;

pub const Game = struct {
    over: bool = false,
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

    pub fn update(self: *Game, screen: *Screen) void {
        self.moveDown(screen);
        self.draw(screen);
    }

    pub fn draw(self: *Game, screen: *Screen) void {
        drawTetrimino(&self.current, screen);
        if (self.current.solid) {
            self.current = Tetrimino.random(&self.prng);
            if (self.hasSolid(screen)) self.over = true;
        }
    }

    pub fn drawTetrimino(block: *Tetrimino, screen: *Screen) void {
        const value = block.position();
        var index: usize = 0;
        while (index < value.len) : (index += 2) {
            const x: usize = @intCast(block.x + value[index]);
            const y: usize = @intCast(block.y + value[index + 1]);
            if (block.solid) {
                screen.drawSolid(x, y, block.color);
            } else {
                screen.draw(x, y, block.color);
            }
        }
    }

    pub fn moveLeft(self: *Game, screen: *Screen) void {
        self.move(-1, 0, screen);
        if (self.hasSolid(screen)) {
            self.move(1, 0, screen);
        }
    }

    pub fn moveRight(self: *Game, screen: *Screen) void {
        self.move(1, 0, screen);
        if (self.hasSolid(screen)) {
            self.move(-1, 0, screen);
        }
    }

    pub fn moveDown(self: *Game, screen: *Screen) void {
        self.move(0, 1, screen);
        if (self.hasSolid(screen)) {
            self.current.solid = true;
            self.move(0, -1, screen);
        }
    }

    fn move(self: *Game, x: i8, y: i8, screen: *Screen) void {
        self.current.x = self.current.x + x;
        self.current.y = self.current.y + y;
        self.current.locateIn(screen.width, screen.height);
    }

    pub fn rotate(self: *Game, screen: *Screen) void {
        var temp = self.current;
        self.current.rotate();
        self.current.locateIn(screen.width, screen.height);
        if (self.hasSolid(screen)) {
            self.current = temp;
        }
    }

    fn hasSolid(self: *Game, screen: *Screen) bool {
        const value = self.current.position();
        var index: usize = 0;
        while (index < value.len) : (index += 2) {
            const row: usize = @intCast(self.current.x + value[index]);
            const col: usize = @intCast(self.current.y + value[index + 1]);
            if (screen.hasSolid(row, col)) return true;
        }
        return false;
    }
};
