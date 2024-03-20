const std = @import("std");
const engine = @import("engine.zig");
const map = @import("map.zig");

const roleSpeed = 100;

pub const Gameplay = struct {
    map: map.WorldMap,

    pub fn update(self: *Gameplay) ?@import("popup.zig").PopupType {
        if (engine.isPressed(engine.Key.x)) return .over;
        if (engine.isPressed(engine.Key.c)) return .clear;

        self.controlPlayer();
        return null;
    }

    fn controlPlayer(self: *Gameplay) void {
        const speed = engine.frameTime() * roleSpeed;
        var p1 = self.map.player1().*;
        if (engine.isDown(engine.Key.a)) {
            p1.x -|= speed;
            const cell = p1.getCell();
            if (!self.map.isCollisionX(cell.x -| 1, cell.y, p1))
                self.map.player1().*.x = p1.x;
        }

        if (engine.isDown(engine.Key.d)) {
            p1.x += speed;
            const cell = p1.getCell();
            if (!self.map.isCollisionX(cell.x + 1, cell.y, p1))
                self.map.player1().*.x = p1.x;
        }

        p1 = self.map.player1().*;
        if (engine.isDown(engine.Key.w)) {
            p1.y -|= speed;
            const cell = p1.getCell();
            if (!self.map.isCollisionY(cell.x, cell.y -| 1, p1))
                self.map.player1().*.y = p1.y;
        }
        if (engine.isDown(engine.Key.s)) {
            p1.y += speed;
            const cell = p1.getCell();
            if (!self.map.isCollisionY(cell.x, cell.y + 1, p1))
                self.map.player1().*.y = p1.y;
        }

        if (engine.isPressed(engine.Key.space)) {
            self.map.setBomb(self.map.player1().*);
        }
    }

    pub fn draw(self: Gameplay) void {
        self.map.draw();
    }

    pub fn deinit(self: Gameplay) void {
        self.map.deinit();
    }
};
