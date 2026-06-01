const std = @import("std");
const zhu = @import("zhu");

const context = @import("context.zig");
const ui = @import("ui.zig");

const NineOption = zhu.batch.NineOption;

const Button = struct {
    const State = enum { normal, hover, pressed };
    label: []const u8,
    offset: zhu.Vector2,
    size: zhu.Vector2,
    normal: zhu.Rect,
    pressed: zhu.Rect,
    nine: NineOption,
};

const buttons: []const Button = @import("zon/title.zon");

var background: zhu.Image = undefined;
var logo: zhu.Image = undefined;
var iconImage: zhu.Image = undefined;
var elapsed: f32 = 0;
var hover: ?usize = null;
var buttonState: Button.State = .normal;
var menuPressed: bool = false;

pub fn init() void {
    background = zhu.getImage("textures/UI/farm-rpg-bg.png").?;
    logo = zhu.getImage("textures/UI/farm-rpg-logo.png").?;
    iconImage = zhu.getImage("farm-rpg/UI/button.png").?;
}

pub fn enter() void {
    zhu.batch.offscreen = false;
    zhu.camera.mode = .window;
    zhu.audio.playMusic("assets/audio/02_spring_fairy_tale.ogg");
}

pub fn exit() void {
    zhu.batch.offscreen = true;
    zhu.camera.mode = .world;
    zhu.audio.setMusicState(.stopped);
}

pub fn update(delta: f32) void {
    if (ui.pause.active) {
        _ = ui.pause.update();
        return;
    }
    elapsed += delta;

    const mousePos = zhu.window.mousePosition;
    for (buttons, 0..) |button, index| {
        const rect = zhu.Rect.init(button.offset, button.size);
        if (!rect.contains(mousePos)) continue;
        // 鼠标进入按钮了
        return updateButton(index);
    }
    hover, buttonState = .{ null, .normal };

    // 右上角菜单按钮：32x32，离右边缘 10，离顶部 10
    const size = zhu.Vector2.xy(32, 32);
    const x = zhu.window.size.x - 10 - size.x;
    const menuRect = zhu.Rect.init(.xy(x, 10), size);
    const contains = menuRect.contains(mousePos);
    menuPressed = contains and zhu.input.mouse.held(.LEFT);
    if (contains and zhu.input.mouse.released(.LEFT)) {
        ui.pause.enter(false);
    }
}

fn updateButton(index: usize) void {
    if (hover == null or hover.? != index) {
        zhu.audio.playSound("assets/audio/Fantasy_UI (1).ogg");
    }
    hover = index;
    const pressed = zhu.window.mouse.held(.LEFT);
    buttonState = if (pressed) .pressed else .hover;

    if (zhu.window.mouse.released(.LEFT)) {
        zhu.audio.playSound("assets/audio/Fantasy_UI (10).ogg");
        switch (index) {
            0 => context.scene.request(.farm),
            1 => std.log.info("load not implemented", .{}),
            2 => zhu.window.exit(),
            else => unreachable,
        }
    }
}

pub fn draw() void {
    { // 背景
        zhu.batch.drawImage(background, .zero, .{
            .size = zhu.window.size,
        });
        const y = 115 + @sin(elapsed * 2) * 5;
        zhu.batch.drawImage(logo, .xy(320, y), .{
            .size = .xy(293, 125),
            .anchor = .center,
        });
    }

    // 按钮
    for (buttons, 0..) |button, index| {
        const rect = zhu.Rect.init(button.offset, button.size);
        const state = if (hover == index) buttonState else .normal;

        // 按钮背景图片
        const image = iconImage.sub(switch (state) {
            .normal, .hover => button.normal,
            .pressed => button.pressed,
        });
        zhu.batch.drawNine(image, rect, button.nine);

        // 按钮文字
        const color: zhu.Color = switch (state) {
            .normal => .white,
            .hover => .{ .r = 0.99, .g = 0.91, .b = 0.53 },
            .pressed => .{ .r = 0.6, .g = 0.6, .b = 0.6 },
        };
        const offset: zhu.Vector2 = switch (state) {
            .normal => zhu.Vector2.zero,
            .hover => .{ .x = 0, .y = -0.5 },
            .pressed => .{ .x = 0, .y = 2 },
        };

        const position = rect.center().add(offset);
        zhu.text.drawString(button.label, position, .{
            .color = color,
            .alignment = .center,
        });
    }

    // 右上角菜单按钮
    const y: f32 = if (menuPressed) 224 else 208;
    const image = iconImage.sub(.init(.xy(432, y), .square(16)));

    const size = zhu.Vector2.xy(32, 32);
    const posX = zhu.window.size.x - 10 - size.x;
    zhu.batch.drawImage(image, .xy(posX, 10), .{ .size = size });

    // 暂停菜单
    if (ui.pause.active) ui.pause.draw();
}
