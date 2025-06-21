const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;

pub const Item = struct {
    id: u16,
    name: []const u8 = &.{},
    about: []const u8 = &.{},
    money: usize = 0,
    exp: usize = 0,
    health: i32 = 0,
    attack: usize = 0,
    defend: i32 = 0,
};

pub const items: []const Item = @import("zon/item.zon");
