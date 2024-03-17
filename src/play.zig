const std = @import("std");
const engine = @import("engine.zig");
const map = @import("map.zig");

const roleSpeed = 100;

pub const Gameplay = struct {
    map: map.WorldMap,

    pub fn update(self: *Gameplay) ?@import("popup.zig").PopupType {
        if (engine.isPressed(engine.Key.x)) return .over;
        if (engine.isPressed(engine.Key.c)) return .clear;

        const speed = engine.frameTime() * roleSpeed;
        var p1 = self.map.player1();
        if (engine.isDown(engine.Key.a)) p1.x -|= speed;
        if (engine.isDown(engine.Key.d)) p1.x +|= speed;
        if (engine.isDown(engine.Key.w)) p1.y -|= speed;
        if (engine.isDown(engine.Key.s)) p1.y +|= speed;

        return null;
    }

    pub fn draw(self: Gameplay) void {
        self.map.draw();
    }

    pub fn deinit(self: Gameplay) void {
        self.map.deinit();
    }
};
