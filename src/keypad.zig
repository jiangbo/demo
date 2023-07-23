const c = @cImport(@cInclude("SDL.h"));
const std = @import("std");

pub const Keypad = struct {
    pub fn new() Keypad {
        return Keypad{};
    }

    pub fn pollEvent(self: *Keypad) ?c.SDL_Event {
        _ = self;
        var event: c.SDL_Event = undefined;
        if (c.SDL_PollEvent(&event) > 0) {
            std.log.info("event type {}\n", .{event});
            return event;
        }

        return null;
    }
};
