const std = @import("std");
const c = @import("c.zig");
const App = @import("obj.zig").App;

pub fn handleInput(app: *App) bool {
    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event) != 0) {
        switch (event.type) {
            c.SDL_QUIT => return true,
            c.SDL_KEYDOWN => doKeyDown(app, &event.key),
            c.SDL_KEYUP => doKeyUp(app, &event.key),
            else => {},
        }
    }
    return false;
}

fn doKeyDown(app: *App, event: *c.SDL_KeyboardEvent) void {
    const code = event.keysym.scancode;
    if (event.repeat == 0 and code < App.MAX_KEYBOARD_KEYS) {
        app.keyboard[code] = true;
    }
}

fn doKeyUp(app: *App, event: *c.SDL_KeyboardEvent) void {
    const code = event.keysym.scancode;
    if (event.repeat == 0 and code < App.MAX_KEYBOARD_KEYS) {
        app.keyboard[code] = false;
    }
}
