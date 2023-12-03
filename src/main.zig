const app = @import("app.zig");
const c = @import("c.zig");

pub fn main() !void {
    var game = app.App.init();
    defer game.deinit();

    var player = app.Entity{ .x = 100, .y = 100 };
    player.init(&game, "gfx/player.png");
    defer player.deinit();

    var bullet = app.Entity{ .x = 100, .y = 100 };
    bullet.init(&game, "gfx/playerBullet.png");
    defer bullet.deinit();

    while (true) {
        _ = c.SDL_SetRenderDrawColor(game.renderer, 96, 128, 255, 255);
        _ = c.SDL_RenderClear(game.renderer);

        if (handleInput(&game)) break;

        if (game.up) player.y -= 4;
        if (game.down) player.y += 4;
        if (game.left) player.x -= 4;
        if (game.right) player.x += 4;

        if (game.fire and !bullet.health) {
            bullet.x = player.x + @divFloor(player.w, 2);
            bullet.y = player.y + @divFloor(player.h, 2);
            bullet.dy = 0;
            bullet.dx = 16;
            bullet.health = true;
        }

        bullet.x += bullet.dx;
        bullet.y += bullet.dy;

        if (bullet.x > app.SCREEN_WIDTH) {
            bullet.health = false;
        }

        player.bound();
        game.blitEntity(&player);

        if (bullet.health) {
            game.blitEntity(&bullet);
        }

        game.present();
    }
}

fn handleInput(game: *app.App) bool {
    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event) != 0) {
        switch (event.type) {
            c.SDL_QUIT => return true,
            c.SDL_KEYDOWN => doKeyDown(game, &event.key),
            c.SDL_KEYUP => doKeyUp(game, &event.key),
            else => {},
        }
    }
    return false;
}

fn doKeyDown(game: *app.App, event: *c.SDL_KeyboardEvent) void {
    if (event.repeat == 0) {
        if (event.keysym.scancode == c.SDL_SCANCODE_UP)
            game.up = true;

        if (event.keysym.scancode == c.SDL_SCANCODE_DOWN)
            game.down = true;

        if (event.keysym.scancode == c.SDL_SCANCODE_LEFT)
            game.left = true;

        if (event.keysym.scancode == c.SDL_SCANCODE_RIGHT)
            game.right = true;

        if (event.keysym.scancode == c.SDL_SCANCODE_LCTRL)
            game.fire = true;
    }
}

fn doKeyUp(game: *app.App, event: *c.SDL_KeyboardEvent) void {
    if (event.repeat == 0) {
        if (event.keysym.scancode == c.SDL_SCANCODE_UP)
            game.up = false;

        if (event.keysym.scancode == c.SDL_SCANCODE_DOWN)
            game.down = false;

        if (event.keysym.scancode == c.SDL_SCANCODE_LEFT)
            game.left = false;

        if (event.keysym.scancode == c.SDL_SCANCODE_RIGHT)
            game.right = false;

        if (event.keysym.scancode == c.SDL_SCANCODE_LCTRL)
            game.fire = false;
    }
}
