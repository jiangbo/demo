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
    current: math.FourDirection = .down,

    pub fn currentAnimation(self: *FourAnimation) *gfx.SliceFrameAnimation {
        return switch (self.current) {
            .up => &self.up,
            .down => &self.down,
            .left => &self.left,
            .right => &self.right,
        };
    }
};

const BASE_URL = "http://127.0.0.1:4444/api";

var playerIndex: i32 = 1;

var animationIdle1: FourAnimation = undefined;
var animationRun1: FourAnimation = undefined;

var animationIdle2: FourAnimation = undefined;
var animationRun2: FourAnimation = undefined;

pub fn init() void {
    animationIdle1 = .{
        .up = .load("assets/hajimi_idle_back_{}.png", 4),
        .down = .load("assets/hajimi_idle_front_{}.png", 4),
        .left = .load("assets/hajimi_idle_left_{}.png", 4),
        .right = .load("assets/hajimi_idle_right_{}.png", 4),
    };

    animationRun1 = .{
        .up = .load("assets/hajimi_run_back_{}.png", 4),
        .down = .load("assets/hajimi_run_front_{}.png", 4),
        .left = .load("assets/hajimi_run_left_{}.png", 4),
        .right = .load("assets/hajimi_run_right_{}.png", 4),
    };

    animationIdle2 = .{
        .up = .load("assets/manbo_idle_back_{}.png", 4),
        .down = .load("assets/manbo_idle_front_{}.png", 4),
        .left = .load("assets/manbo_idle_left_{}.png", 4),
        .right = .load("assets/manbo_idle_right_{}.png", 4),
    };

    animationRun2 = .{
        .up = .load("assets/manbo_run_back_{}.png", 4),
        .down = .load("assets/manbo_run_front_{}.png", 4),
        .left = .load("assets/manbo_run_left_{}.png", 4),
        .right = .load("assets/manbo_run_right_{}.png", 4),
    };

    // playerIndex = http.sendValue(BASE_URL ++ "/login", null);

    audio.playMusic("assets/bgm.ogg");
}

pub fn deinit() void {
    // _ = http.sendValue(BASE_URL ++ "/logout", playerIndex);
    audio.stopMusic();
}

pub fn event(ev: *const window.Event) void {
    _ = ev;
}

pub fn update(delta: f32) void {
    if (playerIndex == 1) {
        animationIdle1.currentAnimation().update(delta);
    } else {
        animationIdle2.currentAnimation().update(delta);
    }

    const sk = @import("sokol");
    std.log.info("scale: {d}, dpi: {}", .{ sk.app.dpiScale(), sk.app.highDpi() });
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    const background = gfx.loadTexture("assets/background.png");
    gfx.draw(background, 0, 0);

    var animation = if (playerIndex == 1) animationIdle1 else animationIdle2;
    gfx.playSlice(animation.currentAnimation(), .{ .x = 100, .y = 100 });
}
