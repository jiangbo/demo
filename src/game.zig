const std = @import("std");
const win32 = @import("win32");
const gfx = @import("gfx.zig");
const Object = @import("sprite.zig").Object;
const Timer = @import("timer.zig").Timer;

const d3d9 = win32.graphics.direct3d9;
const ui = win32.ui.windows_and_messaging;

pub const Game = struct {
    pub const win32Check = gfx.win32Check;
    device: gfx.GraphicsDevice,
    player1: Object,
    player2: Object,
    timer: Timer,

    pub fn init(window: win32.foundation.HWND) Game {
        var device = gfx.GraphicsDevice.init(window);

        var player1: Object = .{
            .name = "Player1",
            .rotation = @as(f32, std.math.pi) / 4,
            .position = .{ .x = 100, .y = 200, .z = 0 },
            .maxSpeed = 90,
        };
        player1.setSpeed(90);
        player1.initSprite(&device, win32.zig.L("assets/PlayerPaper.png"));

        var player2: Object = .{
            .name = "Player2",
            .position = .{ .x = 100, .y = 200, .z = 0 },
            .maxSpeed = 90,
        };
        player2.setSpeed(90);
        player2.initSprite(&device, win32.zig.L("assets/PlayerPaper.png"));

        return .{
            .device = device,
            .player1 = player1,
            .player2 = player2,
            .timer = Timer.init(),
        };
    }

    pub fn run(self: *Game) void {
        self.timer.update();
        self.update(self.timer.elapsed);
        self.draw(self.timer.elapsed);
    }

    fn update(self: *Game, delta: f32) void {
        self.player1.update(delta);
        self.player2.update(delta);
    }

    fn draw(self: *Game, delta: f32) void {
        self.device.begin();
        self.device.clear(0x00006464);

        self.player1.draw(delta);
        self.player2.draw(delta);

        self.device.end();
        self.device.Present();
    }

    pub fn deinit(self: *Game) void {
        self.device.deinit();
        self.player1.deinit();
        self.player2.deinit();
    }
};
