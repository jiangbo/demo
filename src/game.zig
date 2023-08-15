const std = @import("std");
const Screen = @import("screen.zig").Screen;

pub const Facing = enum { North, East, South, West };

pub const Tetrimino = struct {
    facing: Facing, //
    color: enum {
        Red,
    },
};

pub const Game = struct {
    current: Tetrimino,

    pub fn new() Game {
        const current = Tetrimino{
            .facing = .North,
            .color = .Red,
        };
        return Game{ .current = current };
    }

    pub fn update(self: *Game) void {
        _ = self;
    }

    pub fn draw(self: *Game, screen: *Screen) void {
        var cur = self.current;
        _ = cur;
        screen.draw(4, 0, 0xffffffff);
    }
};
