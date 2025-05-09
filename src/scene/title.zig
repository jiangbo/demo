const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const scene = @import("../scene.zig");

var backgrounds: [3]gfx.Texture = undefined;
var currentBackground: u8 = 0;
var timer: window.Timer = .init(5);
var logo: gfx.Texture = undefined;

const Button = struct {
    normal: gfx.Texture,
    hover: gfx.Texture,
};

var buttons: [3]Button = undefined;
var currentButton: u8 = 0;

pub fn init() void {
    backgrounds[0] = gfx.loadTexture("assets/T_bg1.png", .init(800, 600));
    backgrounds[1] = gfx.loadTexture("assets/T_bg2.png", .init(800, 600));
    backgrounds[2] = gfx.loadTexture("assets/T_bg3.png", .init(800, 600));

    logo = gfx.loadTexture("assets/T_logo.png", .init(274, 102));

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
    if (timer.isFinishedAfterUpdate(delta)) {
        currentBackground += 1;
        currentBackground %= backgrounds.len;
        timer.reset();
    }

    if (window.isAnyKeyRelease(&.{ .W, .UP })) currentButton -|= 1;
    if (window.isAnyKeyRelease(&.{ .S, .DOWN })) currentButton += 1;
    currentButton = @min(currentButton, buttons.len - 1);

    if (window.isAnyKeyRelease(&.{ .ENTER, .SPACE })) {
        switch (currentButton) {
            0 => scene.changeScene(),
            1 => std.log.info("load game", .{}),
            2 => window.exit(),
            else => unreachable,
        }
    }
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    gfx.draw(backgrounds[currentBackground], .zero);

    gfx.draw(logo, .init(260, 80));

    for (buttons, 0..) |button, index| {
        const offsetY: f32 = @floatFromInt(350 + index * 50);
        if (currentButton == index) {
            gfx.draw(button.hover, .init(325, offsetY));
        } else {
            gfx.draw(button.normal, .init(325, offsetY));
        }
    }
}
