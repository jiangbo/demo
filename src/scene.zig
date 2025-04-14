const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");
const http = @import("http.zig");

const Player = @import("Player.zig");
const BASE_URL = "http://127.0.0.1:4444/api";
const SPEED = 100;

var text: std.ArrayList(u8) = undefined;
const paths = [_]math.Vector{
    .{ .x = 842, .y = 842 },
    .{ .x = 1322, .y = 842 },
    .{ .x = 1322, .y = 442 },
    .{ .x = 2762, .y = 442 },
    .{ .x = 2762, .y = 842 },
    .{ .x = 3162, .y = 842 },
    .{ .x = 3162, .y = 1722 },
    .{ .x = 2122, .y = 1722 },
    .{ .x = 2122, .y = 1562 },
    .{ .x = 842, .y = 1562 },
};
var totalLength: f32 = 0;
var player1: Player = undefined;
var player2: Player = undefined;

var self: *Player = undefined;
var other: *Player = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    for (paths) |path| {
        totalLength += path.length();
    }

    player1 = Player.init(1);
    player2 = Player.init(2);
    player1.anchorCenter();
    player2.anchorCenter();
    gfx.camera.setSize(.{ .x = window.width, .y = window.height });

    text = http.sendAlloc(allocator, BASE_URL ++ "/text");
    const playerIndex = http.sendValue(BASE_URL ++ "/login", null);
    self = if (playerIndex == 1) &player1 else &player2;
    other = if (playerIndex == 1) &player2 else &player1;
    self.position = paths[0];
    other.position = paths[0];

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
        self.position = self.position.add(direction.scale(SPEED * delta));
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
