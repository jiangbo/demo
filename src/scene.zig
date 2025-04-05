const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const actor = @import("actor.zig");

var player: actor.Player = undefined;

pub fn init() void {
    player = actor.Player.init();
}

pub fn deinit() void {}

pub fn event(ev: *const window.Event) void {
    player.event(ev);
}

pub fn update() void {
    const delta = window.deltaSecond();
    player.update(delta);
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    renderBackground();
    player.render();
}

pub fn renderBackground() void {
    const background = gfx.loadTexture("assets/background.png");
    const width = window.width - background.width();
    const height = window.height - background.height();
    gfx.draw(background, width / 2, height / 2);
}
