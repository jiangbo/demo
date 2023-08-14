const std = @import("std");
const App = @import("app.zig").App;
const c = @import("c.zig");

const WIDTH = 1280;
const HEIGHT = 720;

pub fn main() !void {
    var app = App{ .width = WIDTH, .height = HEIGHT };
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

// fn sdlPanic() noreturn {
//     const str = @as(?[*:0]const u8, c.SDL_GetError());
//     @panic(std.mem.sliceTo(str orelse "unknown error", 0));
// }
