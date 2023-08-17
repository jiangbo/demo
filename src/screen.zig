const std = @import("std");
const c = @import("c.zig");

const WIDTH = 10;
const HEIGHT = 20;

pub const Screen = struct {
    line: usize = 0,
    current_height: usize = HEIGHT,
    width: usize = WIDTH,
    height: usize = HEIGHT,
    scale: u16 = 40,
    border: u16 = 2,
    buffer: [WIDTH][HEIGHT]u32 = undefined,
    window: *c.SDL_Window = undefined,
    renderer: *c.SDL_Renderer = undefined,

    pub fn init(self: *Screen) void {
        self.buffer = std.mem.zeroes([WIDTH][HEIGHT]u32);
        if (c.SDL_Init(c.SDL_INIT_EVERYTHING) < 0) c.sdlPanic();
        if (c.TTF_Init() < 0) c.sdlPanic();
        var font = c.TTF_OpenFont(null, 16);
        std.log.info("font: {?}", .{font});

        const center = c.SDL_WINDOWPOS_CENTERED;
        self.window = c.SDL_CreateWindow("俄罗斯方块", center, center, //
            700, //
            850, c.SDL_WINDOW_SHOWN) //
        orelse c.sdlPanic();
        // self.window = c.SDL_CreateWindow("俄罗斯方块", center, center, //
        //     @intCast(self.width * self.scale), //
        //     @intCast(self.height * self.scale), c.SDL_WINDOW_SHOWN) //
        // orelse c.sdlPanic();

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

    pub fn drawSolid(self: *Screen, x: usize, y: usize, rgba: u32) void {
        self.draw(x, y, rgba);
        self.buffer[x][y] = rgba;
        self.current_height = @min(self.current_height, y);
        if (self.isRowFull(y)) {
            self.clearRow(y);
        }
    }

    fn isRowFull(self: *Screen, y: usize) bool {
        for (0..WIDTH) |x| {
            if (self.buffer[x][y] == 0) return false;
        }
        return true;
    }

    fn clearRow(self: *Screen, y: usize) void {
        var col = y;
        while (col >= self.current_height) : (col -= 1) {
            for (0..WIDTH) |row| {
                self.buffer[row][col] = self.buffer[row][col - 1];
            }
        }
        self.line += 1;
        self.current_height += 1;
    }

    pub fn hasSolid(self: *Screen, x: usize, y: usize) bool {
        if (x >= WIDTH) return false;
        return y >= HEIGHT or self.buffer[x][y] != 0;
    }

    pub fn drawEmpty(self: *Screen, x: usize, y: usize) void {
        _ = c.SDL_SetRenderDrawColor(self.renderer, 40, 40, 40, 0xff);
        self.fillRect(x, y);
    }

    fn fillRect(self: *Screen, x: usize, y: usize) void {
        const rect = c.SDL_Rect{
            .x = @intCast(x * self.scale + self.border + 20),
            .y = @intCast(y * self.scale + self.border + 20),
            .w = @intCast(self.scale - self.border * 2),
            .h = @intCast(self.scale - self.border * 2),
        };
        _ = c.SDL_RenderFillRect(self.renderer, &rect);
    }

    pub fn display(self: *Screen) void {
        self.setColor(0x3b, 0x3b, 0x3b);
        _ = c.SDL_RenderClear(self.renderer);
        for (0..WIDTH) |row| {
            for (0..HEIGHT) |col| {
                const color = self.buffer[row][col];
                if (color == 0) {
                    self.setColor(40, 40, 40);
                    self.fillRect(row, col);
                } else {
                    self.draw(row, col, color);
                }
            }
        }
    }

    pub fn present(self: *Screen, fps: u32) void {
        c.SDL_RenderPresent(self.renderer);
        c.SDL_Delay(1000 / fps);
    }

    pub fn deinit(self: *Screen) void {
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.TTF_Quit();
        c.SDL_Quit();
    }

    fn setColor(self: *Screen, r: u8, g: u8, b: u8) void {
        _ = c.SDL_SetRenderDrawColor(self.renderer, r, g, b, 0xff);
    }
};
