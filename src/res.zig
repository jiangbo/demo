const std = @import("std");
const ray = @import("raylib.zig");

pub var title: ray.Texture = undefined;
pub var box: ray.Texture = undefined;

pub fn init() void {
    title = ray.LoadTexture("data/image/title.dds");
    box = ray.LoadTexture("data/image/box.dds");
}

pub fn deinit() void {
    ray.UnloadTexture(title);
    ray.UnloadTexture(box);
}
