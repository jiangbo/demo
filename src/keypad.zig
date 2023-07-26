const c = @cImport(@cInclude("SDL.h"));

pub const Keypad = struct {
    event: c.SDL_Event = undefined,

    pub fn poll(self: *Keypad) bool {
        while (c.SDL_PollEvent(&self.event) > 0) {
            if (self.event.type == c.SDL_QUIT) return false;
        }
        return true;
    }
};
