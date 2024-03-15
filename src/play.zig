const std = @import("std");
const engine = @import("engine.zig");
const map = @import("map.zig");

pub const Gameplay = struct {
    map: map.WorldMap,

    pub fn update(_: *Gameplay) ?@import("popup.zig").PopupType {
        if (engine.isPressed(engine.Key.x)) return .over;
        if (engine.isPressed(engine.Key.c)) return .clear;
        return null;
    }

    pub fn draw(self: Gameplay) void {
        self.map.draw();
    }

    pub fn deinit(self: Gameplay) void {
        self.map.deinit();
    }
};
