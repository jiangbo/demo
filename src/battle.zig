const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;

const scene = @import("scene.zig");
const map = @import("map.zig");
const context = @import("context.zig");
const npc = @import("npc.zig");

var enemy: u16 = 0;

pub fn enter() void {
    enemy = context.battleNpcIndex;
    map.linkIndex = 13;
    _ = map.enter();
}

pub fn update(delta: f32) void {
    if (window.isKeyRelease(.ESCAPE)) {
        scene.changeScene(.world);
    }

    _ = delta;
}

pub fn draw() void {
    map.draw();
}

pub fn deinit() void {
    npc.deinit();
}
