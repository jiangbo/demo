const std = @import("std");
const c = @import("c.zig");

pub const Screen = struct {
    width: usize = 10,
    height: usize = 20,
    scale: u16 = 40,
    border: u16 = 1,
    window: *c.SDL_Window = undefined,
    renderer: *c.SDL_Renderer = undefined,

    pub fn init(self: *Screen) void {
        if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) c.sdlPanic();
        if (c.TTF_Init() < 0) c.sdlPanic();

        const height: c_int = @intCast(self.height);
        _ = height;

        const center = c.SDL_WINDOWPOS_CENTERED;
        self.window = c.SDL_CreateWindow("俄罗斯方块", center, center, //
            @intCast(self.width * self.scale), //
            @intCast(self.height * self.scale), c.SDL_WINDOW_SHOWN) //
        orelse c.sdlPanic();

        self.renderer = c.SDL_CreateRenderer(self.window, -1, 0) //
        orelse c.sdlPanic();
    }

    pub fn draw(self: *Screen, x: usize, y: usize, rgba: u32) void {
        const r: u8 = @truncate((rgba >> 24) & 0xff);
        const g: u8 = @truncate((rgba >> 16) & 0xff);
        const b: u8 = @truncate((rgba >> 8) & 0xff);
        const a: u8 = @truncate((rgba >> 0) & 0xff);
        _ = c.SDL_SetRenderDrawColor(self.renderer, r, g, b, a);
        self.fillRect(x, y);
    }

    pub fn drawEmpty(self: *Screen, x: usize, y: usize) void {
        _ = c.SDL_SetRenderDrawColor(self.renderer, 40, 40, 40, 0xff);
        self.fillRect(x, y);
    }

    fn fillRect(self: *Screen, x: usize, y: usize) void {
        const rect = c.SDL_Rect{
            .x = @intCast(x * self.scale + self.border),
            .y = @intCast(y * self.scale + self.border),
            .w = @intCast(self.scale - self.border * 2),
            .h = @intCast(self.scale - self.border * 2),
        };
        _ = c.SDL_RenderFillRect(self.renderer, &rect);
    }

    pub fn clear(self: *Screen) void {
        _ = c.SDL_SetRenderDrawColor(self.renderer, 0, 0, 0, 255);
        _ = c.SDL_RenderClear(self.renderer);
    }

    pub fn present(self: *Screen) void {
        c.SDL_RenderPresent(self.renderer);
    }

    pub fn deinit(self: *Screen) void {
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.TTF_Quit();
        c.SDL_Quit();
    }
};
