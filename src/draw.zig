const std = @import("std");
const c = @import("c.zig");
const obj = @import("obj.zig");

const FPS_DURATION = @divFloor(1000, obj.FPS);
var background: *c.SDL_Texture = undefined;

pub fn prepareScene(app: *obj.App) void {
    _ = c.SDL_RenderClear(app.renderer);
    background = c.IMG_LoadTexture(app.renderer, "gfx/background.png") //
    orelse c.panic();
}

pub fn blitEntity(app: *obj.App, entity: *obj.Entity) void {
    var dest = c.SDL_FRect{
        .x = entity.x,
        .y = entity.y,
        .w = entity.w,
        .h = entity.h,
    };

    _ = c.SDL_RenderCopyF(app.renderer, entity.texture, null, &dest);
}

pub fn presentScene(app: *obj.App, startTime: i64) void {
    c.SDL_RenderPresent(app.renderer);
    const delta = std.time.milliTimestamp() - startTime;
    if (delta < FPS_DURATION) c.SDL_Delay(@intCast(FPS_DURATION - delta));
}

pub fn blit(app: *obj.App, texture: *c.SDL_Texture, x: i32, y: i32) void {
    var dest = c.SDL_Rect{ .x = x, .y = y };
    _ = c.SDL_QueryTexture(texture, null, null, &dest.w, &dest.h);

    if (x + dest.w > obj.SCREEN_WIDTH) dest.x = obj.SCREEN_WIDTH - dest.w;
    if (y + dest.h > obj.SCREEN_HEIGHT) dest.y = obj.SCREEN_HEIGHT - dest.h;

    _ = c.SDL_RenderCopy(app.renderer, texture, null, &dest);
    c.SDL_RenderPresent(app.renderer);
}

pub fn blitRect(app: *obj.App, texture: *c.SDL_Texture, src: c.SDL_Rect, x: i32, y: i32) void {
    var dest: c.SDL_Rect = undefined;

    dest.x = x;
    dest.y = y;
    dest.w = src.w;
    dest.h = src.h;

    c.SDL_RenderCopy(app.renderer, texture, src, &dest);
}

pub fn drawBackground(app: *obj.App, backgroundX: i32) void {
    var dest: c.SDL_Rect = undefined;
    var x: i32 = backgroundX;

    while (x < obj.SCREEN_WIDTH) : (x += obj.SCREEN_WIDTH) {
        dest.x = x;
        dest.y = 0;
        dest.w = obj.SCREEN_WIDTH;
        dest.h = obj.SCREEN_HEIGHT;
        _ = c.SDL_RenderCopy(app.renderer, background, null, &dest);
    }
}

pub fn drawStars(app: *obj.App, stars: []obj.Star) void {
    for (stars) |v| {
        const rgb = 32 *% @as(u8, @intCast(v.speed));
        _ = c.SDL_SetRenderDrawColor(app.renderer, rgb, rgb, rgb, 255);
        _ = c.SDL_RenderDrawLine(app.renderer, v.x, v.y, v.x + 3, v.y);
    }
}
