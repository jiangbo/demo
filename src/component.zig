const std = @import("std");
const ray = @import("raylib.zig");

pub const Player = struct {};

pub const Image = struct {
    x: usize = 0,
    y: usize = 0,
    texture: ray.Texture2D,
};
