const std = @import("std");

pub const Facing = enum { North, East, South, West };
// pub const Kind = enum { O, I, T, L, J, S, Z };

const tetriminoes: [7]Tetrimino = label: {
    var arr: [7]Tetrimino = undefined;
    arr[0] = .{ .value = .{
        .{ 0, 1, 1, 1, 2, 1, 3, 1 },
        .{ 2, 0, 2, 1, 2, 2, 2, 3 },
        .{ 0, 2, 1, 2, 2, 2, 3, 2 },
        .{ 1, 0, 1, 1, 1, 2, 1, 3 },
    }, .color = 0xffaa00ff };
    arr[1] = .{ .value = .{
        .{ 0, 1, 1, 1, 2, 1, 3, 1 },
        .{ 2, 0, 2, 1, 2, 2, 2, 3 },
        .{ 0, 2, 1, 2, 2, 2, 3, 2 },
        .{ 1, 0, 1, 1, 1, 2, 1, 3 },
    }, .color = 0xffaa00ff };
    arr[2] = .{ .value = .{
        .{ 0, 1, 1, 1, 2, 1, 3, 1 },
        .{ 2, 0, 2, 1, 2, 2, 2, 3 },
        .{ 0, 2, 1, 2, 2, 2, 3, 2 },
        .{ 1, 0, 1, 1, 1, 2, 1, 3 },
    }, .color = 0xffaa00ff };
    arr[3] = .{ .value = .{
        .{ 0, 1, 1, 1, 2, 1, 3, 1 },
        .{ 2, 0, 2, 1, 2, 2, 2, 3 },
        .{ 0, 2, 1, 2, 2, 2, 3, 2 },
        .{ 1, 0, 1, 1, 1, 2, 1, 3 },
    }, .color = 0xffaa00ff };
    arr[4] = .{ .value = .{
        .{ 0, 1, 1, 1, 2, 1, 3, 1 },
        .{ 2, 0, 2, 1, 2, 2, 2, 3 },
        .{ 0, 2, 1, 2, 2, 2, 3, 2 },
        .{ 1, 0, 1, 1, 1, 2, 1, 3 },
    }, .color = 0xffaa00ff };
    arr[5] = .{ .value = .{
        .{ 0, 1, 1, 1, 2, 1, 3, 1 },
        .{ 2, 0, 2, 1, 2, 2, 2, 3 },
        .{ 0, 2, 1, 2, 2, 2, 3, 2 },
        .{ 1, 0, 1, 1, 1, 2, 1, 3 },
    }, .color = 0xffaa00ff };
    arr[6] = .{ .value = .{
        .{ 0, 1, 1, 1, 2, 1, 3, 1 },
        .{ 2, 0, 2, 1, 2, 2, 2, 3 },
        .{ 0, 2, 1, 2, 2, 2, 3, 2 },
        .{ 1, 0, 1, 1, 1, 2, 1, 3 },
    }, .color = 0xffaa00ff };
    // arr[0] = Tetrimino{ .kind = Kind{ .O = O{} } };
    // arr[1] = Tetrimino{ .kind = Kind{ .I = I{} } };
    // arr[2] = Tetrimino{ .kind = Kind{ .T = T{} } };
    // arr[3] = Tetrimino{ .kind = Kind{ .L = L{} } };
    // arr[4] = Tetrimino{ .kind = Kind{ .J = J{} } };
    // arr[5] = Tetrimino{ .kind = Kind{ .S = S{} } };
    // arr[6] = Tetrimino{ .kind = Kind{ .Z = Z{} } };
    break :label arr;
};

// const O = struct {
//     value: [8][4]u8 = .{
//         .{ 0, 1, 1, 1, 2, 1, 3, 1 },
//         .{ 2, 0, 2, 1, 2, 2, 2, 3 },
//         .{ 0, 2, 1, 2, 2, 2, 3, 2 },
//         .{ 1, 0, 1, 1, 1, 2, 1, 3 },
//     },
//     color: u32 = 0xffaa00ff,
// };

// const I = struct {
//     value: [8][4]u8 = .{
//         .{ 0, 1, 1, 1, 2, 1, 3, 1 },
//         .{ 2, 0, 2, 1, 2, 2, 2, 3 },
//         .{ 0, 2, 1, 2, 2, 2, 3, 2 },
//         .{ 1, 0, 1, 1, 1, 2, 1, 3 },
//     },
//     color: u32 = 0xffaa00ff,
// };

// const T = struct {
//     value: [8][4]u8 = .{
//         .{ 0, 1, 1, 1, 2, 1, 3, 1 },
//         .{ 2, 0, 2, 1, 2, 2, 2, 3 },
//         .{ 0, 2, 1, 2, 2, 2, 3, 2 },
//         .{ 1, 0, 1, 1, 1, 2, 1, 3 },
//     },
//     color: u32 = 0xffaa00ff,
// };

// const L = struct {
//     value: [8][4]u8 = .{
//         .{ 0, 1, 1, 1, 2, 1, 3, 1 },
//         .{ 2, 0, 2, 1, 2, 2, 2, 3 },
//         .{ 0, 2, 1, 2, 2, 2, 3, 2 },
//         .{ 1, 0, 1, 1, 1, 2, 1, 3 },
//     },
//     color: u32 = 0xffaa00ff,
// };

// const J = struct {
//     value: [8][4]u8 = .{
//         .{ 0, 1, 1, 1, 2, 1, 3, 1 },
//         .{ 2, 0, 2, 1, 2, 2, 2, 3 },
//         .{ 0, 2, 1, 2, 2, 2, 3, 2 },
//         .{ 1, 0, 1, 1, 1, 2, 1, 3 },
//     },
//     color: u32 = 0xffaa00ff,
// };

// const S = struct {
//     value: [8][4]u8 = .{
//         .{ 0, 1, 1, 1, 2, 1, 3, 1 },
//         .{ 2, 0, 2, 1, 2, 2, 2, 3 },
//         .{ 0, 2, 1, 2, 2, 2, 3, 2 },
//         .{ 1, 0, 1, 1, 1, 2, 1, 3 },
//     },
//     color: u32 = 0xffaa00ff,
// };

// const Z = struct {
//     value: [8][4]u8 = .{
//         .{ 0, 1, 1, 1, 2, 1, 3, 1 },
//         .{ 2, 0, 2, 1, 2, 2, 2, 3 },
//         .{ 0, 2, 1, 2, 2, 2, 3, 2 },
//         .{ 1, 0, 1, 1, 1, 2, 1, 3 },
//     },
//     color: u32 = 0xffaa00ff,
// };

// pub const Kind = union(enum) {
//     O: O,
//     I: I,
//     T: T,
//     L: L,
//     J: J,
//     S: S,
//     Z: Z,
// };

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
        return tetriminoes[prng.random().uintAtMost(usize, 7)];
    }
};
