const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");
const http = @import("http.zig");

const Player = @import("Player.zig");
const BASE_URL = "http://127.0.0.1:4444/api";
const SPEED = 100;

var cameraScene: gfx.Camera = .{};
var cameraUI: gfx.Camera = .{};

var text: std.ArrayList(u8) = undefined;
var lines: std.BoundedArray([]const u8, 100) = undefined;
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
var totalChar: usize = 0;
var currentLine: u8 = 0;
var currentChar: u8 = 0;

var player1: Player = undefined;
var player2: Player = undefined;

var self: *Player = undefined;
var other: *Player = undefined;

var textbox: gfx.Texture = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    cameraScene.setSize(window.size);
    cameraUI.setSize(window.size);

    for (0..paths.len - 1) |index| {
        totalLength += paths[index + 1].sub(paths[index]).length();
    }

    player1 = Player.init(1);
    player2 = Player.init(2);
    player1.anchorCenter();
    player2.anchorCenter();

    text = http.sendAlloc(allocator, BASE_URL ++ "/text");
    lines = std.BoundedArray([]const u8, 100).init(0) catch unreachable;

    var iter = std.mem.tokenizeScalar(u8, text.items, '\n');
    while (iter.next()) |line| {
        lines.appendAssumeCapacity(line);
        totalChar += line.len;
    }

    const playerIndex = http.sendValue(BASE_URL ++ "/login", null);
    self = if (playerIndex == 1) &player1 else &player2;
    other = if (playerIndex == 1) &player2 else &player1;
    self.position = paths[0];
    other.position = paths[0];

    textbox = gfx.loadTexture("assets/ui_textbox.png");

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
        const position: math.Vector = switch (key) {
            .up => .{ .y = -SPEED * delta },
            .down => .{ .y = SPEED * delta },
            .left => .{ .x = -SPEED * delta },
            .right => .{ .x = SPEED * delta },
        };
        self.current = key;
        self.position = self.position.add(position);
    }

    cameraScene.lookAt(self.position);

    self.currentAnimation().update(delta);
    other.currentAnimation().update(delta);
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    gfx.camera = cameraScene;
    const background = gfx.loadTexture("assets/background.png");
    gfx.draw(background, 0, 0);

    gfx.playSlice(other.currentAnimation(), other.position);
    gfx.playSlice(self.currentAnimation(), self.position);

    gfx.camera = cameraUI;
    gfx.draw(textbox, 0, 720 - textbox.height());
}
