const std = @import("std");
const stage = @import("stage.zig");
const App = @import("obj.zig").App;

pub fn main() !void {
    var app = App.init();
    defer app.deinit();

    stage.initStage(&app, std.heap.c_allocator);
    defer stage.deinitStage();

    while (true) {
        const start = std.time.milliTimestamp();
        stage.prepareScene(&app);

        if (stage.handleInput(&app)) break;

        stage.logicStage(&app);

        stage.drawStage(&app);

        stage.presentScene(&app, start);
    }
}
