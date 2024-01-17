const std = @import("std");
const c = @import("c.zig");
const obj = @import("obj.zig");

const FPS_DURATION = @divFloor(1000, obj.FPS);
var background: *c.SDL_Texture = undefined;
var explosion: *c.SDL_Texture = undefined;

pub fn prepareScene(app: *obj.App) void {
    _ = c.SDL_RenderClear(app.renderer);
    background = c.IMG_LoadTexture(app.renderer, "gfx/background.png") //
    orelse c.panic();
    explosion = c.IMG_LoadTexture(app.renderer, "gfx/explosion.png") //
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
    std.log.info("delta time ms: {}", .{delta});
    if (delta < FPS_DURATION) c.SDL_Delay(@intCast(FPS_DURATION - delta));
}

pub fn blit(app: *obj.App, texture: *c.SDL_Texture, x: i32, y: i32) void {
    var dest = c.SDL_Rect{ .x = x, .y = y };
    _ = c.SDL_QueryTexture(texture, null, null, &dest.w, &dest.h);

    if (x + dest.w > obj.SCREEN_WIDTH) dest.x = obj.SCREEN_WIDTH - dest.w;
    if (y + dest.h > obj.SCREEN_HEIGHT) dest.y = obj.SCREEN_HEIGHT - dest.h;

    _ = c.SDL_RenderCopy(app.renderer, texture, null, &dest);
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

pub fn drawExplosion(app: *obj.App, list: obj.ExplosionList) void {
    if (list.len == 0) return;

    _ = c.SDL_SetRenderDrawBlendMode(app.renderer, c.SDL_BLENDMODE_ADD);
    _ = c.SDL_SetTextureBlendMode(explosion, c.SDL_BLENDMODE_ADD);

    var it = list.first;
    while (it) |node| : (it = node.next) {
        const data = node.data;
        _ = c.SDL_SetTextureColorMod(explosion, data.r, data.g, data.b);
        _ = c.SDL_SetTextureAlphaMod(explosion, data.a);
        const x: i32 = @intFromFloat(data.x);
        const y: i32 = @intFromFloat(data.y);
        blit(app, explosion, x, y);
    }

    _ = c.SDL_SetRenderDrawBlendMode(app.renderer, c.SDL_BLENDMODE_NONE);
}
