const c = @cImport(@cInclude("SDL.h"));
const std = @import("std");

pub const Screen = struct {
    scale: u8,
    window: *c.SDL_Window = undefined,
    renderder: *c.SDL_Renderer = undefined,

    pub fn new() Screen {
        return Screen{
            .scale = 0,
        };
    }

    pub fn init(self: *Screen) void {
        std.log.info("init screen", .{});
        if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0)
            @panic("sdl init failed");

        self.window = c.SDL_CreateWindow("chip8", c.SDL_WINDOWPOS_CENTERED,
        //
        c.SDL_WINDOWPOS_CENTERED, 640, 400, c.SDL_WINDOW_SHOWN)
        //
        orelse @panic("create window failed");

        self.renderder = c.SDL_CreateRenderer(self.window, -1, 0)
        //
        orelse @panic("create renderer failed");
    }

    pub fn deinit(self: *Screen) void {
        std.log.info("deinit screen", .{});
        c.SDL_DestroyRenderer(self.renderder);
        c.SDL_DestroyWindow(self.window);
    }
};
