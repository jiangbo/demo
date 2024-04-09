const std = @import("std");
const engine = @import("engine.zig");

const dir = "assets/";
pub var dungeon: engine.Texture = undefined;

pub fn init() void {
    dungeon = engine.Texture.init(dir ++ "dungeonfont.png");
}

pub fn deinit() void {
    dungeon.deinit();
}
