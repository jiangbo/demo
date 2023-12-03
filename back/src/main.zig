const std = @import("std");
const sdl = @import("sdl2");

pub fn main() !void {
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_EVENTS | sdl.SDL_INIT_AUDIO) < 0)
        sdlPanic();
    defer sdl.SDL_Quit();

    var window = sdl.SDL_CreateWindow(
        "SDL2 Native Demo",
        sdl.SDL_WINDOWPOS_CENTERED,
        sdl.SDL_WINDOWPOS_CENTERED,
        640,
        480,
        sdl.SDL_WINDOW_SHOWN,
    ) orelse sdlPanic();
    defer _ = sdl.SDL_DestroyWindow(window);

    var renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_ACCELERATED) orelse sdlPanic();
    defer _ = sdl.SDL_DestroyRenderer(renderer);

    mainLoop: while (true) {
        var ev: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&ev) != 0) {
            if (ev.type == sdl.SDL_QUIT)
                break :mainLoop;
        }

        _ = sdl.SDL_SetRenderDrawColor(renderer, 0xF7, 0xA4, 0x1D, 0xFF);
        _ = sdl.SDL_RenderClear(renderer);

        sdl.SDL_RenderPresent(renderer);
    }
}

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, sdl.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}
