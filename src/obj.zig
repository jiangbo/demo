const c = @import("c.zig");
const std = @import("std");

pub const SCREEN_WIDTH = 1280;
pub const SCREEN_HEIGHT = 720;

pub const Entity = struct {
    x: f32,
    y: f32,
    w: i32 = 0,
    h: i32 = 0,
    dx: f32 = 0,
    dy: f32 = 0,
    health: bool = false,
    reload: i32 = 0,
    enemy: bool = true,
    texture: *c.SDL_Texture = undefined,

    pub fn initPosition(self: *Entity, x: f32, y: f32) void {
        self.x = x;
        self.y = y;
    }

    pub fn copy(self: *Entity, other: *Entity) void {
        self.dx = other.dx;
        self.health = other.health;
        self.texture = other.texture;
        self.enemy = other.enemy;
        self.w = other.w;
        self.h = other.h;
    }

    pub fn initTexture(self: *Entity, app: *App, file: [*c]const u8) void {
        std.log.info("loading {s}", .{file});
        self.texture = c.IMG_LoadTexture(app.renderer, file) orelse c.panic();
        _ = c.SDL_QueryTexture(self.texture, null, null, &self.w, &self.h);
    }

    pub fn deinit(self: *Entity) void {
        c.SDL_DestroyTexture(self.texture);
    }
};

pub const App = struct {
    pub const MAX_KEYBOARD_KEYS = 350;

    renderer: *c.SDL_Renderer,
    window: *c.SDL_Window,
    keyboard: [MAX_KEYBOARD_KEYS]bool = undefined,

    pub fn init() App {
        if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) c.panic();

        if (c.IMG_Init(c.IMG_INIT_JPG | c.IMG_INIT_PNG) < 0) c.panic();

        const pos = c.SDL_WINDOWPOS_UNDEFINED;
        const window = c.SDL_CreateWindow("射击游戏", pos, pos, //
            SCREEN_WIDTH, SCREEN_HEIGHT, 0) orelse c.panic();

        const r = c.SDL_CreateRenderer(window, -1, 0) orelse c.panic();
        return App{ .window = window, .renderer = r };
    }

    pub fn deinit(self: *App) void {
        c.IMG_Quit();
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }
};
