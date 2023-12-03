pub usingnamespace @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_image.h");
});

const std = @import("std");
pub fn panic() noreturn {
    const str = @as(?[*:0]const u8, @This().SDL_GetError());
    @panic(std.mem.sliceTo(str orelse "unknown error", 0));
}
