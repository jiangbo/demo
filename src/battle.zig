const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;

const scene = @import("scene.zig");
const map = @import("map.zig");

var oldLink: u16 = 0;
var enemy: u16 = 0;

pub fn enter(old: u16, npc: u16) void {
    oldLink = old;
    enemy = npc;
    map.linkIndex = 13;
    scene.changeMap();
}

pub fn update() void {
    if (window.isKeyRelease(.ESCAPE)) {
        map.linkIndex = oldLink;
        scene.changeMap();
    }
}

pub fn draw() void {
    map.draw();
}
