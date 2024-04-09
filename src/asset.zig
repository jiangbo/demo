const std = @import("std");
const ray = @import("raylib.zig");

pub var dungeon: ray.Texture2D = undefined;

pub fn init() void {
    dungeon = ray.LoadTexture("assets/dungeonfont.png");
}

pub fn deinit() void {
    ray.UnloadTexture(dungeon);
}
