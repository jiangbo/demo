const std = @import("std");
const App = @import("app.zig").App;
const c = @import("c.zig");

pub fn main() !void {
    var app = App{};
    app.init();
    defer app.deinit();
    mainLoop: while (true) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            if (event.type == c.SDL_QUIT)
                break :mainLoop;
        }

        _ = c.SDL_SetRenderDrawColor(app.renderer, 96, 128, 255, 255);
        _ = c.SDL_RenderClear(app.renderer);

        c.SDL_RenderPresent(app.renderer);
    }
}
