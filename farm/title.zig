const std = @import("std");
const zhu = @import("zhu");

const context = @import("context.zig");

const NineOption = zhu.batch.NineOption;

const Event = enum { start, load, exit };
const ButtonState = enum { normal, hover, pressed };

const Button = struct {
    label: []const u8,
    offset: zhu.Vector2,
    size: zhu.Vector2,
    normal: zhu.Rect,
    hover: zhu.Rect,
    pressed: zhu.Rect,
    nine: NineOption,
    event: Event,
};

const Config = struct {
    hoverSound: [:0]const u8,
    clickSound: [:0]const u8,
    textNormal: zhu.Color,
    textHover: zhu.Color,
    textPressed: zhu.Color,
    textHoverOffset: zhu.Vector2,
    textPressedOffset: zhu.Vector2,
    buttons: []const Button,
};

const zon: Config = @import("zon/title.zon");

var background: zhu.Image = undefined;
var logo: zhu.Image = undefined;
var buttonImage: zhu.Image = undefined;
var elapsed: f32 = 0;
var hoverIndex: ?usize = null;
var buttonState: ButtonState = .normal;

pub fn init() void {
    background = zhu.getImage("textures/UI/farm-rpg-bg.png").?;
    logo = zhu.getImage("textures/UI/farm-rpg-logo.png").?;
    buttonImage = zhu.getImage("farm-rpg/UI/button.png").?;
}

pub fn enter() void {
    zhu.batch.offscreen = false;
}

pub fn exit() void {
    zhu.batch.offscreen = true;
}

pub fn update(delta: f32) void {
    elapsed += delta;

    const mousePos = zhu.window.mousePosition;
    const press = zhu.window.mouse.down(.LEFT);
    for (zon.buttons, 0..) |button, index| {
        const rect = zhu.Rect.init(button.offset, button.size);
        if (!rect.contains(mousePos)) continue;

        if (updateButton(index, press, button.event)) return;
        return;
    }

    if (!press) {
        hoverIndex = null;
        buttonState = .normal;
    }
}

pub fn draw() void {
    const previousMode = zhu.camera.mode;
    zhu.camera.mode = .window;
    defer zhu.camera.mode = previousMode;

    zhu.batch.drawImage(background, .zero, .{ .size = zhu.window.size });

    const y = 115 + @sin(elapsed * 2) * 5;
    zhu.batch.drawImage(logo, .xy(320, y), .{
        .size = .xy(293, 125),
        .anchor = .center,
    });

    for (zon.buttons, 0..) |button, index| drawButton(button, index);
}

fn updateButton(index: usize, press: bool, event: Event) bool {
    if (hoverIndex == null or hoverIndex.? != index) {
        zhu.audio.playSound(zon.hoverSound);
    }
    hoverIndex = index;
    buttonState = if (press) .pressed else .hover;

    if (!zhu.window.mouse.released(.LEFT)) return false;
    zhu.audio.playSound(zon.clickSound);
    handleEvent(event);
    return true;
}

fn handleEvent(event: Event) void {
    switch (event) {
        .start => context.scene.request(.farm),
        .load => std.log.info("title load clicked: not implemented", .{}),
        .exit => zhu.window.exit(),
    }
}

fn drawButton(button: Button, index: usize) void {
    const rect = zhu.Rect.init(button.offset, button.size);
    const state = if (hoverIndex == index) buttonState else .normal;
    const source = switch (state) {
        .normal => button.normal,
        .hover => button.hover,
        .pressed => button.pressed,
    };

    zhu.batch.drawNine(buttonImage.sub(source), rect, button.nine);

    const color = switch (state) {
        .normal => zon.textNormal,
        .hover => zon.textHover,
        .pressed => zon.textPressed,
    };
    const offset = switch (state) {
        .normal => zhu.Vector2.zero,
        .hover => zon.textHoverOffset,
        .pressed => zon.textPressedOffset,
    };
    drawTextCenter(button.label, rect, color, offset);
}

fn drawTextCenter(
    text: []const u8,
    rect: zhu.Rect,
    color: zhu.Color,
    offset: zhu.Vector2,
) void {
    const option = zhu.text.Option{ .color = color };
    const size = zhu.text.measure(text, option);
    const position = rect.min.add(rect.size.sub(size).scale(0.5)).add(offset);
    zhu.text.drawString(text, position, option);
}
