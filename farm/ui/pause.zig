const zhu = @import("zhu");

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
    event: Event,
};

const Icon = struct {
    offset: zhu.Vector2,
    size: zhu.Vector2,
    normal: zhu.Rect,
    pressed: zhu.Rect,
    event: Event,
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

var disabledSaveLoad: bool = false;
pub fn enter(disabled: bool) void {
    active = true;
    disabledSaveLoad = disabled;
}

pub fn update() ?Event {
    const panel = zhu.Rect.init(
        zhu.window.size.sub(zon.size).scale(0.5),
        zon.size,
    );
    const mousePos = zhu.window.mousePosition;

    for (zon.buttons, 0..) |button, index| {
        if (getButtonState(index) == .disabled) continue; // 禁用按钮不响应交互
        const rect = zhu.Rect.init(panel.min.add(button.offset), button.size);
        if (!rect.contains(mousePos)) continue;
        return updateButton(index, button.event);
    }

    const startIndex = zon.buttons.len;
    for (zon.rows, 0..) |row, rowIndex| {
        const rowRect = zhu.Rect.init(panel.min.add(row.offset), row.size);

        const leftRect = zhu.Rect.init(
            rowRect.min.add(row.left.offset),
            row.left.size,
        );
        const leftIndex = startIndex + rowIndex * 2;
        if (leftRect.contains(mousePos)) {
            return updateButton(leftIndex, row.left.event);
        }

        const rightRect = zhu.Rect.init(
            rowRect.min.add(row.right.offset),
            row.right.size,
        );
        const rightIndex = leftIndex + 1;
        if (rightRect.contains(mousePos)) {
            return updateButton(rightIndex, row.right.event);
        }
    }

    hover, buttonState = .{ null, .normal };
    return null;
}

pub fn draw() void {
    zhu.camera.layer = .text;
    defer zhu.camera.layer = .default;

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
    for (zon.rows) |row| {
        const rect = zhu.Rect.init(start.add(row.offset), row.size);
        zhu.text.drawString(row.label, rect.center(), .{
            .alignment = .center,
        });
    }
}

// Save 按钮 index=1, Load 按钮 index=2
fn getButtonState(index: usize) Button.State {
    if (disabledSaveLoad) {
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

fn updateButton(index: usize, event: Event) ?Event {
    if (hover == null or hover.? != index) {
        zhu.audio.playSound("assets/audio/Fantasy_UI (1).ogg");
    }
    hover = index;
    const pressed = zhu.window.mouse.held(.LEFT);
    buttonState = if (pressed) .pressed else .hover;

    if (!zhu.window.mouse.released(.LEFT)) return null;
    zhu.audio.playSound("assets/audio/Fantasy_UI (10).ogg");
    return event;
}

fn drawIcon(pos: zhu.Vector2, icon: Icon, index: usize) void {
    const position = pos.add(icon.offset);
    const pressed = hover == index and buttonState == .pressed;
    const source = if (pressed) icon.pressed else icon.normal;
    const option: zhu.batch.Option = .{ .size = icon.size };
    zhu.batch.drawImage(image.sub(source), position, option);
}
