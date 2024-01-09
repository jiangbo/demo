const std = @import("std");
const c = @import("c.zig");
const obj = @import("obj.zig");

const FPS = 60;
const FPS_DURATION = @divFloor(1000, FPS);

pub fn prepareScene(app: *obj.App) void {
    _ = c.SDL_SetRenderDrawColor(app.renderer, 96, 128, 255, 255);
    _ = c.SDL_RenderClear(app.renderer);
}

pub fn blitEntity(app: *obj.App, entity: *obj.Entity) void {
    var dest = c.SDL_FRect{
        .x = entity.x,
        .y = entity.y,
        .w = @floatFromInt(entity.w),
        .h = @floatFromInt(entity.h),
    };

    _ = c.SDL_RenderCopyF(app.renderer, entity.texture, null, &dest);
}

pub fn presentScene(app: *obj.App, startTime: i64) void {
    c.SDL_RenderPresent(app.renderer);
    const delta = std.time.milliTimestamp() - startTime;
    if (delta < FPS_DURATION) c.SDL_Delay(@intCast(FPS_DURATION - delta));
}

pub fn blit(self: *obj.App, texture: *c.SDL_Texture, x: i32, y: i32) void {
    var dest = c.SDL_Rect{ .x = x, .y = y };
    _ = c.SDL_QueryTexture(texture, null, null, &dest.w, &dest.h);

    if (x + dest.w > obj.SCREEN_WIDTH) dest.x = obj.SCREEN_WIDTH - dest.w;
    if (y + dest.h > obj.SCREEN_HEIGHT) dest.y = obj.SCREEN_HEIGHT - dest.h;

    _ = c.SDL_RenderCopy(self.renderer, texture, null, &dest);
    c.SDL_RenderPresent(self.renderer);
}
