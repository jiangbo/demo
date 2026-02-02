const std = @import("std");
const zhu = @import("zhu");

const map = @import("map.zig");

pub fn init() void {
    map.init();
}

pub fn deinit() void {
    map.deinit();
}

pub fn update(delta: f32) void {
    map.update(delta);
}

pub fn draw() void {
    map.draw();
}
