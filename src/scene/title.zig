const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");

var background1: gfx.Texture = undefined;

var start1: gfx.Texture = undefined;
var start2: gfx.Texture = undefined;

var load1: gfx.Texture = undefined;
var load2: gfx.Texture = undefined;

var exit1: gfx.Texture = undefined;
var exit2: gfx.Texture = undefined;

const Button = struct {
    normal: gfx.Texture,
    hover: gfx.Texture,
};

var buttons: [3]Button = undefined;
var currentButton: u7 = 0;

pub fn init() void {
    background1 = gfx.loadTexture("assets/T_bg1.png", .init(800, 600));

    buttons[0] = .{
        .normal = gfx.loadTexture("assets/T_start_1.png", .init(142, 36)),
        .hover = gfx.loadTexture("assets/T_start_2.png", .init(142, 36)),
    };

    buttons[1] = .{
        .normal = gfx.loadTexture("assets/T_load_1.png", .init(142, 36)),
        .hover = gfx.loadTexture("assets/T_load_2.png", .init(142, 36)),
    };

    buttons[2] = .{
        .normal = gfx.loadTexture("assets/T_exit_1.png", .init(142, 36)),
        .hover = gfx.loadTexture("assets/T_exit_2.png", .init(142, 36)),
    };
}

pub fn enter() void {
    currentButton = 0;
    window.playMusic("assets/2.ogg");
}

pub fn exit() void {
    window.stopMusic();
}

pub fn update(delta: f32) void {
    _ = delta;

    if (window.isAnyKeyRelease(&.{ .W, .UP })) currentButton -|= 1;
    if (window.isAnyKeyRelease(&.{ .S, .DOWN })) currentButton += 1;
    currentButton = @min(currentButton, buttons.len - 1);
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    gfx.draw(background1, .zero);

    for (buttons, 0..) |button, index| {
        const offsetY: f32 = @floatFromInt(350 + index * 50);
        if (currentButton == index) {
            gfx.draw(button.hover, .init(325, offsetY));
        } else {
            gfx.draw(button.normal, .init(325, offsetY));
        }
    }
}
