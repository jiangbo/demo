const std = @import("std");
const c = @import("c.zig");

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn new(rgba: u32) Color {
        return Color{
            .r = @truncate((rgba >> 24) & 0xff),
            .g = @truncate((rgba >> 16) & 0xff),
            .b = @truncate((rgba >> 8) & 0xff),
            .a = @truncate((rgba >> 0) & 0xff),
        };
    }
};

pub const Screen = struct {
    width: usize = 10,
    height: usize = 20,
    scale: u16 = 40,
    window: *c.SDL_Window = undefined,
    renderer: *c.SDL_Renderer = undefined,

    pub fn init(self: *Screen) void {
        if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) c.sdlPanic();
        if (c.TTF_Init() < 0) c.sdlPanic();

        const width: c_int = @intCast(self.width);
        const height: c_int = @intCast(self.height);

        const center = c.SDL_WINDOWPOS_CENTERED;
        self.window = c.SDL_CreateWindow("俄罗斯方块", center, center, //
            width * self.scale, height * self.scale, //
            c.SDL_WINDOW_SHOWN) orelse c.sdlPanic();

        self.renderer = c.SDL_CreateRenderer(self.window, -1, 0) //
        orelse c.sdlPanic();
        _ = c.SDL_RenderSetLogicalSize(self.renderer, width, height);
    }

    pub fn draw(self: *Screen, x: usize, y: usize, rgba: u32) void {
        const color = Color.new(rgba);
        _ = c.SDL_SetRenderDrawColor(self.renderer, //
            color.r, color.g, color.b, color.a);
        _ = c.SDL_RenderDrawPoint(self.renderer, @intCast(x), @intCast(y));
    }

    pub fn clear(self: *Screen) void {
        _ = c.SDL_SetRenderDrawColor(self.renderer, 96, 128, 255, 255);
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
