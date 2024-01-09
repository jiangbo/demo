const std = @import("std");
const obj = @import("obj.zig");
const input = @import("input.zig");
const stage = @import("stage.zig");

pub fn main() !void {
    var app = obj.App.init();
    defer app.deinit();

    const allocator = std.heap.c_allocator;
    try stage.initStage(&app, allocator);
    defer stage.deinitStage();

    while (true) {
        const start = std.time.milliTimestamp();
        stage.prepareScene(&app);
        if (input.handleInput(&app)) break;

        stage.logicStage(&app);

        stage.drawStage(&app);

        stage.presentScene(&app, start);
    }
}
