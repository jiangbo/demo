const std = @import("std");
const zhu = @import("zhu");

const tiled = zhu.extend.tiled;

const level: tiled.Map = @import("zon/level1.zon");

pub fn init() void {
    tiled.backgroundColor = level.backgroundColor;
}

pub fn deinit() void {}

pub fn update(delta: f32) void {
    _ = delta;
}

pub fn draw() void {}
