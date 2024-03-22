const std = @import("std");
const engine = @import("engine.zig");
const map = @import("map.zig");

const playerSpeed = 100;

pub const Gameplay = struct {
    map: map.Map,

    pub fn init(level: usize) ?Gameplay {
        const m = map.Map.init(level) orelse return null;
        return Gameplay{ .map = m };
    }

    pub fn update(self: *Gameplay) ?@import("popup.zig").PopupType {
        self.map.update();
        if (!self.map.player1().alive) return .over;
        if (engine.isPressed(engine.Key.c)) return .clear;

        const speed = engine.frameTime() * playerSpeed;

        if (engine.isDown(engine.Key.a)) self.map.control(speed, .west);
        if (engine.isDown(engine.Key.d)) self.map.control(speed, .east);
        if (engine.isDown(engine.Key.w)) self.map.control(speed, .north);
        if (engine.isDown(engine.Key.s)) self.map.control(speed, .south);

        if (engine.isPressed(engine.Key.space)) {
            self.map.setBomb(self.map.player1());
        }

        return null;
    }

    pub fn draw(self: Gameplay) void {
        self.map.draw();
    }

    pub fn deinit(self: *Gameplay) void {
        self.map.deinit();
    }
};
