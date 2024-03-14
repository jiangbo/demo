const std = @import("std");
const engine = @import("engine.zig");
const state = @import("state.zig");

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    engine.init(640, 480, "炸弹人");
    defer engine.deinit();
    engine.withAllocator(gpa.allocator());

    var mainState = state.State.init(gpa.allocator());
    defer mainState.deinit();

    while (engine.shoudContinue()) {
        mainState.update();
        mainState.draw();
    }
}
