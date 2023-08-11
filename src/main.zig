const std = @import("std");
const c = @cImport({
    @cInclude("SDL.h");
});

const WIDTH = 1280;
const HEIGHT = 720;

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) sdlPanic();
    defer c.SDL_Quit();

    // if (c.IMG_Init(c.IMG_INIT_PNG | c.IMG_INIT_JPG) < 0) sdlPanic();
    // defer c.IMG_Quit();

    // texture = c.IMG_LoadTexture(app.renderer, filename);
    const pos = c.SDL_WINDOWPOS_CENTERED;
    var window = c.SDL_CreateWindow("射击", pos, pos, WIDTH, HEIGHT, //
        c.SDL_WINDOW_SHOWN) orelse sdlPanic();
    defer c.SDL_DestroyWindow(window);

    _ = c.SDL_SetHint(c.SDL_HINT_RENDER_SCALE_QUALITY, "linear");
    var renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse sdlPanic();
    defer c.SDL_DestroyRenderer(renderer);

    mainLoop: while (true) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            if (event.type == c.SDL_QUIT)
                break :mainLoop;
        }

        _ = c.SDL_SetRenderDrawColor(renderer, 96, 128, 255, 255);
        _ = c.SDL_RenderClear(renderer);

        c.SDL_RenderPresent(renderer);
    }
}

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, c.SDL_GetError());
    @panic(std.mem.sliceTo(str orelse "unknown error", 0));
}
