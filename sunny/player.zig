const std = @import("std");
const zhu = @import("zhu");

const size: zhu.Vector2 = .xy(32, 32);
var image: zhu.graphics.Image = undefined;

var position: zhu.Vector2 = undefined;

pub fn init(pos: zhu.Vector2) void {
    position = pos;
    const foxy = zhu.getImage("textures/Actors/foxy.png");
    image = foxy.sub(.init(.zero, size));
}

pub fn update(delta: f32) void {
    _ = delta;
}

pub fn draw() void {
    zhu.batch.drawImage(image, position, .{});
}
