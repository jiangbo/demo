const std = @import("std");

pub const Facing = enum { North, East, South, West };
// pub const Kind = enum { O, I, T, L, J, S, Z };

const tetriminoes: [7]Tetrimino = label: {
    var arr: [7]Tetrimino = undefined;
    // I
    arr[0] = .{ .value = .{
        .{ 0, 1, 1, 1, 2, 1, 3, 1 },
        .{ 2, 0, 2, 1, 2, 2, 2, 3 },
        .{ 0, 2, 1, 2, 2, 2, 3, 2 },
        .{ 1, 0, 1, 1, 1, 2, 1, 3 },
    }, .color = 0x00ffffff };
    // J
    arr[1] = .{ .value = .{
        .{ 0, 0, 0, 1, 1, 1, 2, 1 },
        .{ 1, 0, 2, 0, 1, 1, 1, 2 },
        .{ 0, 1, 1, 1, 2, 1, 2, 2 },
        .{ 1, 0, 1, 1, 0, 2, 1, 2 },
    }, .color = 0x0000ffff };
    // L
    arr[2] = .{ .value = .{
        .{ 2, 0, 0, 1, 1, 1, 2, 1 },
        .{ 1, 0, 1, 1, 1, 2, 2, 2 },
        .{ 0, 1, 1, 1, 2, 1, 0, 2 },
        .{ 0, 0, 1, 0, 1, 1, 1, 2 },
    }, .color = 0xffaa00ff };
    // O
    arr[3] = .{ .value = .{
        .{ 1, 0, 2, 0, 1, 1, 2, 1 },
        .{ 1, 0, 2, 0, 1, 1, 2, 1 },
        .{ 1, 0, 2, 0, 1, 1, 2, 1 },
        .{ 1, 0, 2, 0, 1, 1, 2, 1 },
    }, .color = 0xffff00ff };
    // S
    arr[4] = .{ .value = .{
        .{ 1, 0, 2, 0, 0, 1, 1, 1 },
        .{ 1, 0, 1, 1, 2, 1, 2, 2 },
        .{ 1, 1, 2, 1, 0, 2, 1, 2 },
        .{ 0, 0, 0, 1, 1, 1, 1, 2 },
    }, .color = 0x00ff00ff };
    // T
    arr[5] = .{ .value = .{
        .{ 1, 0, 0, 1, 1, 1, 2, 1 },
        .{ 1, 0, 1, 1, 2, 1, 1, 2 },
        .{ 0, 1, 1, 1, 2, 1, 1, 2 },
        .{ 1, 0, 0, 1, 1, 1, 1, 2 },
    }, .color = 0x9900ffff };
    // Z
    arr[6] = .{ .value = .{
        .{ 0, 0, 1, 0, 1, 1, 2, 1 },
        .{ 2, 0, 1, 1, 2, 1, 1, 2 },
        .{ 0, 1, 1, 1, 1, 2, 2, 2 },
        .{ 1, 0, 0, 1, 1, 1, 0, 2 },
    }, .color = 0xff0000ff };
    break :label arr;
};

pub const Tetrimino = struct {
    x: usize = 0,
    y: usize = 0,
    facing: Facing = .North,
    value: [4][8]u8 = undefined,
    color: u32,

    pub fn position(self: *Tetrimino) [8]u8 {
        return self.value[@intFromEnum(self.facing)];
    }

    pub fn random() Tetrimino {
        const seed = @as(u64, @intCast(std.time.timestamp()));
        var prng = std.rand.DefaultPrng.init(seed);
        const len = tetriminoes.len;
        return tetriminoes[prng.random().uintLessThan(usize, len)];
    }
};
