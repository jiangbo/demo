const std = @import("std");
const zhu = @import("zhu");

const state = @import("state.zig");
const ui = @import("ui.zig");

const menus: []const zhu.widget.Menu = @import("zon/menu.zon");

pub const Request = union(enum) { start, load: u8 };
const Button = enum(u8) { start, load, exit };
const Popup = enum { pause, save };

var mainMenu: zhu.widget.Menu = menus[0];
var pauseButton: zhu.widget.Menu = menus[1];
var background: zhu.Image = undefined;
var logo: zhu.Image = undefined;
var elapsed: f32 = 0;
var popup: ?Popup = null;

pub fn init() void {
    const bgPath = "textures/UI/farm-rpg-bg.png";
    background = zhu.assets.loadImage(bgPath, .xy(1280, 800));
    logo = zhu.getImage("textures/UI/farm-rpg-logo.png").?;
    const size = pauseButton.buttons[0].rect.size;
    pauseButton.position = .xy(zhu.window.size.x - 10 - size.x, 10);
}

pub fn enter() void {
    zhu.camera.main = .window;
    zhu.audio.playMusic("audio/02_spring_fairy_tale.ogg");
    elapsed = 0;
    popup = null;
}

pub fn exit() void {
    zhu.audio.setMusicState(.stopped);
}

pub fn update(delta: f32) ?Request {
    elapsed += delta;

    if (popup) |active| return updatePopup(active);

    const pauseKey = state.input.pressed(.pause);
    if (pauseKey or pauseButton.update(.{}) != null) {
        ui.pause.open(.title);
        popup = .pause;
        return null;
    }

    if (mainMenu.update(.{})) |value| {
        switch (@as(Button, @enumFromInt(value))) {
            .start => return .start,
            .load => {
                ui.save.open(.load);
                popup = .save;
            },
            .exit => zhu.window.exit(),
        }
    }
    return null;
}

fn updatePopup(active: Popup) ?Request {
    switch (active) {
        .pause => {
            if (ui.pause.update()) |req| switch (req) {
                .close => popup = null,
                .save, .load => unreachable,
                .title => unreachable,
            };
        },
        .save => {
            if (ui.save.update()) |req| switch (req) {
                .close => popup = null,
                .load => |slot| return .{ .load = slot },
                .save => unreachable,
            };
        },
    }
    return null;
}

pub fn draw() void {
    zhu.batch.drawImage(background, .zero, .{
        .size = zhu.window.size,
    });
    const y = 115 + @sin(elapsed * 2) * 5;
    zhu.batch.drawImage(logo, .xy(320, y), .{
        .size = .xy(293, 125),
        .anchor = .center,
    });

    mainMenu.draw();
    pauseButton.draw();
    switch (popup orelse return) {
        .pause => ui.pause.draw(),
        .save => ui.save.draw(),
    }
}
