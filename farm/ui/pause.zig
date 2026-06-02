const std = @import("std");
const zhu = @import("zhu");

const context = @import("../context.zig");
const save = @import("../save.zig");

const ImageId = zhu.graphics.ImageId;
const NineOption = zhu.batch.NineOption;

pub const Event = enum {
    resumeGame,
    save,
    load,
    title,
    speedDown,
    speedUp,
    musicDown,
    musicUp,
    sfxDown,
    sfxUp,
};

const Button = struct {
    const State = enum { normal, hover, pressed, disabled };
    label: []const u8,
    offset: zhu.Vector2,
    size: zhu.Vector2,
    normal: zhu.Rect,
    hover: zhu.Rect,
    pressed: zhu.Rect,
    nine: NineOption,
};

const Icon = struct {
    offset: zhu.Vector2,
    size: zhu.Vector2,
    normal: zhu.Rect,
    pressed: zhu.Rect,
};

const Row = struct {
    label: []const u8,
    offset: zhu.Vector2,
    size: zhu.Vector2,
    left: Icon,
    right: Icon,
};

const Config = struct {
    size: zhu.Vector2,
    buttons: []const Button,
    rows: []const Row,
};

const zon: Config = @import("../zon/pause.zon");

pub var active: bool = false;

var image: zhu.Image = undefined;
var hover: ?usize = null;
var buttonState: Button.State = .normal;

pub fn init() void {
    image = zhu.getImage("farm-rpg/UI/button.png").?;
}

var disableSaveLoad: bool = false;
pub fn enter(disable: bool) void {
    active = true;
    disableSaveLoad = disable;
}

pub fn update(world: *zhu.ecs.World) void {
    const panelPos = zhu.window.size.sub(zon.size).scale(0.5);
    const panel = zhu.Rect.init(panelPos, zon.size);
    const mousePos = zhu.window.mousePosition;

    for (zon.buttons, 0..) |button, index| {
        if (getButtonState(index) == .disabled) continue; // 禁用按钮不响应交互
        const buttonPos = panel.min.add(button.offset);
        const rect = zhu.Rect.init(buttonPos, button.size);
        if (!rect.contains(mousePos)) continue;
        return updateButton(world, index);
    }

    for (zon.rows, 0..) |row, rowIndex| {
        const rowPos = panel.min.add(row.offset);

        const leftIndex = zon.buttons.len + rowIndex * 2;
        const leftPos = rowPos.add(row.left.offset);
        const leftRect = zhu.Rect.init(leftPos, row.left.size);
        if (leftRect.contains(mousePos)) {
            return updateButton(world, leftIndex);
        }

        const rightPos = rowPos.add(row.right.offset);
        const rightRect = zhu.Rect.init(rightPos, row.right.size);
        if (rightRect.contains(mousePos)) {
            return updateButton(world, leftIndex + 1);
        }
    }

    hover, buttonState = .{ null, .normal };
}

pub fn draw() void {
    // 全屏覆盖
    const overlay = zhu.Rect.init(.zero, zhu.window.size);
    zhu.batch.drawRect(overlay, .{ .color = .gray(0, 0.35) });

    // 暂停面板背景
    const start = zhu.window.size.sub(zon.size).scale(0.5);
    const back = zhu.Rect.init(start, zon.size);
    zhu.batch.drawRect(back, .{ .color = .gray(0, 0.45) });

    // 按钮的图片和icon
    drawButtonImage(start);
    for (zon.rows, 0..) |row, index| {
        const startIndex = zon.buttons.len + index * 2;
        const pos = start.add(row.offset);
        drawIcon(pos, row.left, startIndex);
        drawIcon(pos, row.right, startIndex + 1);
    }

    // 将图片和文字分开绘制，避免多次 draw call
    drawButtonText(start);
    for (zon.rows, 0..) |row, index| {

        // 动态文本
        var buffer: [40]u8 = undefined;
        const string: []const u8 = switch (index) {
            0 => zhu.format(&buffer, "Speed {d:.2}x", .{
                context.time.scale,
            }),
            1 => zhu.format(&buffer, "Music {d:.0}%", .{
                zhu.audio.musicVolume.load(.acquire) * 100,
            }),
            2 => zhu.format(&buffer, "SFX {d:.0}%", .{
                zhu.audio.soundVolume.load(.acquire) * 100,
            }),
            else => unreachable,
        };

        const rect = zhu.Rect.init(start.add(row.offset), row.size);
        zhu.text.drawString(string, rect.center(), .{
            .alignment = .center,
        });
    }
}

// Save 按钮 index=1, Load 按钮 index=2
fn getButtonState(index: usize) Button.State {
    if (disableSaveLoad) {
        if (index == 1 or index == 2) return .disabled;
    }
    return if (hover == index) buttonState else .normal;
}

fn drawButtonImage(start: zhu.Vector2) void {
    for (zon.buttons, 0..) |*button, index| {
        const position = start.add(button.offset);
        const rect = zhu.Rect.init(position, button.size);

        const state = getButtonState(index);
        const source = switch (state) {
            .normal, .hover, .disabled => button.normal,
            .pressed => button.pressed,
        };

        zhu.batch.drawNine(image.sub(source), rect, button.nine);
    }
}
fn drawButtonText(start: zhu.Vector2) void {
    for (zon.buttons, 0..) |button, index| {
        const position = start.add(button.offset);
        const rect = zhu.Rect.init(position, button.size);

        const state = getButtonState(index);
        const color: zhu.Color = switch (state) {
            .normal => .white,
            .hover => .rgba(0.99, 0.91, 0.53, 1),
            .pressed => .gray(0.6, 1),
            .disabled => .gray(0.4, 1),
        };

        const center = rect.center();
        zhu.text.drawString(button.label, center, .{
            .color = color,
            .alignment = .center,
        });
    }
}

fn updateButton(world: *zhu.ecs.World, index: usize) void {
    if (hover == null or hover.? != index) {
        zhu.audio.playSound("assets/audio/Fantasy_UI (1).ogg");
    }
    hover = index;
    const pressed = zhu.window.mouse.held(.LEFT);
    buttonState = if (pressed) .pressed else .hover;

    if (zhu.window.mouse.released(.LEFT)) {
        zhu.audio.playSound("assets/audio/Fantasy_UI (10).ogg");
        switch (index) {
            0 => active = false, // 继续游戏
            1 => save.saveSlot(world) catch |err| {
                std.log.err("save failed: {}", .{err});
            },
            2 => save.loadSlot(world) catch |err| {
                std.log.err("load failed: {}", .{err});
            },
            3 => context.scene.request(.title), // 返回标题
            4 => context.time.scale -= 0.1, // 减速
            5 => context.time.scale += 0.1, // 加速
            6 => zhu.audio.changeMusicVolume(-0.1), // 减小音乐
            7 => zhu.audio.changeMusicVolume(0.1), // 增大音乐
            8 => zhu.audio.changeSoundVolume(-0.1), // 减小音效
            9 => zhu.audio.changeSoundVolume(0.1), // 增加音效
            else => unreachable,
        }
    }
}

fn drawIcon(pos: zhu.Vector2, icon: Icon, index: usize) void {
    const position = pos.add(icon.offset);
    const pressed = hover == index and buttonState == .pressed;
    const source = if (pressed) icon.pressed else icon.normal;
    const option: zhu.batch.Option = .{ .size = icon.size };
    zhu.batch.drawImage(image.sub(source), position, option);
}
