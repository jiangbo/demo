// const c = @import("c.zig");
// const std = @import("std");

// pub const SCREEN_WIDTH = 1280;
// pub const SCREEN_HEIGHT = 720;

// const FPS = 60;
// const FPS_DURATION = @divFloor(1000, FPS);
// const MAX_KEYBOARD_KEYS = 350;
// const PLAYER_SPEED = 4;
// const PLAYER_BULLET_SPEED = 16;

// pub const Delegate = struct {
//     logic: fn (void) void,
//     draw: fn (void) void,
// };

// const Stage = struct {
//     fighterHead: Entity,
//     fighterTail: *Entity,
//     bulletHead: Entity,
//     bulletTail: *Entity,
// };

// pub const Entity = struct {
//     x: f64,
//     y: f64,
//     w: i32 = 0,
//     h: i32 = 0,
//     dx: f64 = 0,
//     dy: f64 = 0,
//     health: bool = false,
//     reload: i32 = 0,
//     texture: *c.SDL_Texture = undefined,
//     next: ?*Entity = null,

//     pub fn init(self: *Entity, game: *App, file: [*c]const u8) void {
//         std.log.info("loading {s}", .{file});
//         self.texture = c.IMG_LoadTexture(game.renderer, file) orelse c.panic();
//         _ = c.SDL_QueryTexture(self.texture, null, null, &self.w, &self.h);
//     }

//     pub fn bound(self: *Entity) void {
//         if (self.x < 0) self.x = 0;
//         if (self.y < 0) self.y = 0;

//         if (self.x + self.w > SCREEN_WIDTH) self.x = SCREEN_WIDTH - self.w;
//         if (self.y + self.h > SCREEN_HEIGHT) self.y = SCREEN_HEIGHT - self.h;
//     }

//     pub fn deinit(self: *Entity) void {
//         c.SDL_DestroyTexture(self.texture);
//     }
// };

// pub const App = struct {
//     renderer: *c.SDL_Renderer,
//     window: *c.SDL_Window,
//     delegate: Delegate,
//     keyboard: [MAX_KEYBOARD_KEYS]i32,

//     pub fn init() App {
//         if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) c.panic();

//         if (c.IMG_Init(c.IMG_INIT_JPG | c.IMG_INIT_PNG) < 0) c.panic();

//         const pos = c.SDL_WINDOWPOS_UNDEFINED;
//         const window = c.SDL_CreateWindow("射击游戏", pos, pos, //
//             SCREEN_WIDTH, SCREEN_HEIGHT, 0) orelse c.panic();

//         const r = c.SDL_CreateRenderer(window, -1, 0) orelse c.panic();
//         return App{ .window = window, .renderer = r };
//     }

//     pub fn blitEntity(self: *App, entity: *Entity) void {
//         var dest = c.SDL_Rect{
//             .x = entity.x,
//             .y = entity.y,
//             .w = entity.w,
//             .h = entity.h,
//         };

//         _ = c.SDL_RenderCopy(self.renderer, entity.texture, null, &dest);
//     }

//     pub fn blit(self: *App, texture: *c.SDL_Texture, x: i32, y: i32) void {
//         var dest = c.SDL_Rect{ .x = x, .y = y };
//         _ = c.SDL_QueryTexture(texture, null, null, &dest.w, &dest.h);

//         if (x + dest.w > SCREEN_WIDTH) dest.x = SCREEN_WIDTH - dest.w;
//         if (y + dest.h > SCREEN_HEIGHT) dest.y = SCREEN_HEIGHT - dest.h;

//         _ = c.SDL_RenderCopy(self.renderer, texture, null, &dest);
//         c.SDL_RenderPresent(self.renderer);
//     }

//     pub fn present(self: *App, startTime: i64) void {
//         c.SDL_RenderPresent(self.renderer);
//         const delta = std.time.milliTimestamp() - startTime;
//         if (delta < FPS_DURATION) c.SDL_Delay(@intCast(FPS_DURATION - delta));
//     }

//     pub fn deinit(self: *App) void {
//         c.IMG_Quit();
//         c.SDL_DestroyRenderer(self.renderer);
//         c.SDL_DestroyWindow(self.window);
//         c.SDL_Quit();
//     }
// };
