const std = @import("std");
const c = @import("c.zig");

pub const App = struct {
    width: c_int,
    height: c_int,
    window: *c.SDL_Window = undefined,
    renderer: *c.SDL_Renderer = undefined,

    pub fn init(self: *App) void {
        if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0)
            sdlPanic();

        const center = c.SDL_WINDOWPOS_CENTERED;
        self.window = c.SDL_CreateWindow("射击", center, center, //
            self.width, self.height, c.SDL_WINDOW_SHOWN) orelse sdlPanic();

        self.renderer = c.SDL_CreateRenderer(self.window, -1, 0) //
        orelse sdlPanic();
    }

    pub fn deinit(self: *App) void {
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }
};

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, c.SDL_GetError());
    @panic(std.mem.sliceTo(str orelse "unknown error", 0));
}
