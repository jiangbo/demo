const std = @import("std");
const Screen = @import("screen.zig").Screen;
const Tetrimino = @import("block.zig").Tetrimino;

pub const Game = struct {
    over: bool = false,
    current: Tetrimino,
    next: Tetrimino,
    prng: std.rand.DefaultPrng,
    score: usize = 100,
    pub fn new() Game {
        const seed = @as(u64, @intCast(std.time.timestamp()));
        var rand = std.rand.DefaultPrng.init(seed);
        return Game{
            .current = Tetrimino.random(&rand),
            .next = Tetrimino.random(&rand),
            .prng = rand,
        };
    }

    pub fn update(self: *Game, screen: *Screen) void {
        self.moveDown(screen);
        self.drawTetrimino(screen);
    }

    pub fn drawTetrimino(self: *Game, screen: *Screen) void {
        draw(&self.current, screen, self.current.x, self.current.y);
        draw(&self.next, screen, 450, 600);
        if (self.current.solid) {
            self.current = self.next;
            self.next = Tetrimino.random(&self.prng);
            if (self.hasSolid(screen)) self.over = true;
        }
    }

    fn draw(block: *Tetrimino, screen: *Screen, x: i32, y: i32) void {
        const value = block.position();
        var index: usize = 0;
        while (index < value.len) : (index += 2) {
            const row: usize = @intCast(x + value[index]);
            const col: usize = @intCast(y + value[index + 1]);
            if (block.solid) {
                screen.drawSolid(row, col, block.color);
            } else {
                screen.draw(row, col, block.color);
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
            const col = self.current.y + value[index + 1];
            if (col < 0) return true;
            const row: usize = @intCast(self.current.x + value[index]);
            if (screen.hasSolid(row, @intCast(col))) return true;
        }
        return false;
    }
};
