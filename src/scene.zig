const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");
const http = @import("http.zig");

const FourAnimation = struct {
    up: gfx.SliceFrameAnimation,
    down: gfx.SliceFrameAnimation,
    left: gfx.SliceFrameAnimation,
    right: gfx.SliceFrameAnimation,
};

const BASE_URL = "http://127.0.0.1:4444/api";
const SPEED = 1;

const Player = struct {
    index: i32,
    position: math.Vector = .{ .x = 400, .y = 400 },
    idle: FourAnimation,
    run: FourAnimation,
    keydown: ?math.FourDirection = null,
    current: math.FourDirection = .down,

    fn init(index: i32) Player {
        if (index == 1) return .{
            .index = index,
            .idle = .{
                .up = .load("assets/hajimi_idle_back_{}.png", 4),
                .down = .load("assets/hajimi_idle_front_{}.png", 4),
                .left = .load("assets/hajimi_idle_left_{}.png", 4),
                .right = .load("assets/hajimi_idle_right_{}.png", 4),
            },

            .run = .{
                .up = .load("assets/hajimi_run_back_{}.png", 4),
                .down = .load("assets/hajimi_run_front_{}.png", 4),
                .left = .load("assets/hajimi_run_left_{}.png", 4),
                .right = .load("assets/hajimi_run_right_{}.png", 4),
            },
        };

        return .{
            .index = index,
            .idle = .{
                .up = .load("assets/manbo_idle_back_{}.png", 4),
                .down = .load("assets/manbo_idle_front_{}.png", 4),
                .left = .load("assets/manbo_idle_left_{}.png", 4),
                .right = .load("assets/manbo_idle_right_{}.png", 4),
            },

            .run = .{
                .up = .load("assets/manbo_run_back_{}.png", 4),
                .down = .load("assets/manbo_run_front_{}.png", 4),
                .left = .load("assets/manbo_run_left_{}.png", 4),
                .right = .load("assets/manbo_run_right_{}.png", 4),
            },
        };
    }

    pub fn currentAnimation(player: *Player) *gfx.SliceFrameAnimation {
        var animation = if (player.keydown == null) &player.idle else &player.run;

        return switch (player.current) {
            .up => &animation.up,
            .down => &animation.down,
            .left => &animation.left,
            .right => &animation.right,
        };
    }
};

var text: std.ArrayList(u8) = undefined;
var player1: Player = undefined;
var player2: Player = undefined;

var self: *Player = undefined;
var other: *Player = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    player1 = Player.init(1);
    player2 = Player.init(2);
    gfx.camera.setSize(.{ .x = window.width, .y = window.height });

    text = http.sendAlloc(allocator, BASE_URL ++ "/text");
    const playerIndex = http.sendValue(BASE_URL ++ "/login", null);
    self = if (playerIndex == 1) &player1 else &player2;
    other = if (playerIndex == 1) &player2 else &player1;

    audio.playMusic("assets/bgm.ogg");
}

pub fn deinit() void {
    _ = http.sendValue(BASE_URL ++ "/logout", self.index);
    text.deinit();
    audio.stopMusic();
}

pub fn event(ev: *const window.Event) void {
    if (ev.type == .KEY_DOWN) {
        switch (ev.key_code) {
            .A, .LEFT => self.keydown = .left,
            .D, .RIGHT => self.keydown = .right,
            .W, .UP => self.keydown = .up,
            .S, .DOWN => self.keydown = .down,
            else => {},
        }
    } else if (ev.type == .KEY_UP) {
        switch (ev.key_code) {
            .A, .LEFT, .D, .RIGHT => self.keydown = null,
            .W, .UP, .S, .DOWN => self.keydown = null,
            else => {},
        }
    }
}

pub fn update(delta: f32) void {
    if (self.keydown) |key| {
        const direction: math.Vector = switch (key) {
            .up => .{ .y = -1 },
            .down => .{ .y = 1 },
            .left => .{ .x = -1 },
            .right => .{ .x = 1 },
        };
        self.current = key;
        self.position = self.position.add(direction.scale(SPEED));
    }

    gfx.camera.lookAt(self.position);

    self.currentAnimation().update(delta);
    other.currentAnimation().update(delta);
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    const background = gfx.loadTexture("assets/background.png");
    gfx.draw(background, 0, 0);

    gfx.playSlice(other.currentAnimation(), other.position);
    gfx.playSlice(self.currentAnimation(), self.position);
}
