const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const camera = zhu.camera;

var texture: gfx.Texture = undefined;

pub fn init() void {
    texture = gfx.loadTexture("assets/image/bonus_life.png", .init(87, 87));
}

pub fn update() void {}

pub fn draw() void {}
