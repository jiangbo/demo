const std = @import("std");
const input = @import("input.zig");
const stage = @import("stage.zig");

const App = @import("obj.zig").App;

pub fn main() !void {
    var app = App.init();
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
