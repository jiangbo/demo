const zhu = @import("zhu");

const map = @import("map.zig");

pub fn init() void {}
pub fn deinit() void {}

pub fn enter() void {
    map.init(0);
}

pub fn exit() void {
    map.deinit();
}

pub fn update(delta: f32) void {
    map.update(delta);
}

pub fn draw() void {
    map.draw();
}
