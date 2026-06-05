const std = @import("std");
const zhu = @import("zhu");

const context = @import("context.zig");
const ui = @import("ui.zig");

const MenuEvent = enum(u8) { start, load, exit };

var background: zhu.Image = undefined;
var logo: zhu.Image = undefined;
var iconImage: zhu.Image = undefined;
var elapsed: f32 = 0;
var menuPressed: bool = false;
var menu: zhu.widget.Menu = @import("zon/title.zon");

pub fn init() void {
    background = zhu.getImage("textures/UI/farm-rpg-bg.png").?;
    logo = zhu.getImage("textures/UI/farm-rpg-logo.png").?;
    iconImage = zhu.getImage("farm-rpg/UI/button.png").?;
}

pub fn enter() void {
    zhu.camera.mode = .window;
    zhu.audio.playMusic("assets/audio/02_spring_fairy_tale.ogg");
    menu.reset();
    menuPressed = false;
}

pub fn exit() void {
    zhu.camera.mode = .world;
    zhu.audio.setMusicState(.stopped);
}

pub fn update(delta: f32) void {
    elapsed += delta;

    if (menu.update()) |event| {
        switch (@as(MenuEvent, @enumFromInt(event))) {
            .start => context.scene.requestNewGame(),
            .load => ui.save_slot.enter(.titleLoad),
            .exit => zhu.window.exit(),
        }
    }

    // 右上角菜单按钮：32x32，离右边缘 10，离顶部 10
    const mousePos = zhu.window.mouse;
    const size = zhu.Vector2.xy(32, 32);
    const x = zhu.window.size.x - 10 - size.x;
    const menuRect = zhu.Rect.init(.xy(x, 10), size);
    const contains = menuRect.contains(mousePos);
    menuPressed = contains and zhu.mouse.held(.LEFT);
    if (contains and zhu.mouse.released(.LEFT)) {
        ui.pause.enter(true);
    }
}

pub fn draw() void {
    // 背景
    zhu.batch.drawImage(background, .zero, .{
        .size = zhu.window.size,
    });
    var y = 115 + @sin(elapsed * 2) * 5;
    zhu.batch.drawImage(logo, .xy(320, y), .{
        .size = .xy(293, 125),
        .anchor = .center,
    });

    // 右上角菜单按钮
    y = if (menuPressed) 224 else 208;
    const image = iconImage.sub(.init(.xy(432, y), .square(16)));

    const size = zhu.Vector2.xy(32, 32);
    const posX = zhu.window.size.x - 10 - size.x;
    zhu.batch.drawImage(image, .xy(posX, 10), .{ .size = size });

    menu.draw();
}
