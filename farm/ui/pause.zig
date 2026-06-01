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
var buttonState: ButtonState = .normal;

pub fn init() void {
    image = zhu.getImage("farm-rpg/UI/button.png").?;
}

var enableSave: bool = false;
pub fn enter(save: bool) void {
    active = true;
    enableSave = save;
}

pub fn update() ?Event {
    const panel = zhu.Rect.init(zhu.window.size.sub(zon.size).scale(0.5), zon.size);
    const mousePos = zhu.window.mousePosition;
    const press = zhu.window.mouse.held(.LEFT);

    for (zon.buttons, 0..) |button, index| {
        const rect = zhu.Rect.init(panel.min.add(button.offset), button.size);
        if (!rect.contains(mousePos)) continue;
        return updateButton(index, press, button.event);
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
            return updateButton(leftIndex, press, row.left.event);
        }

        const rightRect = zhu.Rect.init(
            rowRect.min.add(row.right.offset),
            row.right.size,
        );
        const rightIndex = leftIndex + 1;
        if (rightRect.contains(mousePos)) {
            return updateButton(rightIndex, press, row.right.event);
        }
    }

    if (!press) {
        hover = null;
        buttonState = .normal;
    }
    return null;
}

pub fn draw() void {
    zhu.camera.layer = .text;
    defer zhu.camera.layer = .default;

    const overlay = zhu.Rect.init(.zero, zhu.window.size);
    zhu.batch.drawRect(overlay, .{ .color = .gray(0, 0.35) });

    const pos = zhu.window.size.sub(zon.size).scale(0.5);
    const back = zhu.Rect.init(pos, zon.size);
    zhu.batch.drawRect(back, .{ .color = .gray(0, 0.45) });

    drawButtonImage(pos);
    drawButtonText(pos);

    // for (zon.rows, 0..) |row, index| drawRow(pos, row, index);
}

fn drawButtonImage(start: zhu.Vector2) void {
    for (zon.buttons, 0..) |*button, index| {
        const position = start.add(button.offset);
        const rect = zhu.Rect.init(position, button.size);
        const state = if (hover == index) buttonState else .normal;

        const source = switch (state) {
            .normal, .hover => button.normal,
            .pressed => button.pressed,
        };

        zhu.batch.drawNine(image.sub(source), rect, button.nine);
    }
}
fn drawButtonText(start: zhu.Vector2) void {
    for (zon.buttons, 0..) |button, index| {
        const position = start.add(button.offset);
        const rect = zhu.Rect.init(position, button.size);
        const state = if (hover == index) buttonState else .normal;
        const color: zhu.Color = switch (state) {
            .normal => .white,
            .hover => .rgba(0.99, 0.91, 0.53, 1),
            .pressed => .gray(0.6, 1),
        };
        const offset: zhu.Vector2 = switch (state) {
            .normal => .zero,
            .hover => .xy(0, -0.5),
            .pressed => .xy(0, 2),
        };
        const center = rect.center().add(offset);
        zhu.text.drawString(button.label, center, .{
            .color = color,
            .alignment = .center,
        });
    }
}

fn updateButton(index: usize, press: bool, event: Event) ?Event {
    if (hover == null or hover.? != index) {
        zhu.audio.playSound("assets/audio/Fantasy_UI (1).ogg");
    }
    hover = index;
    buttonState = if (press) .pressed else .hover;

    if (!zhu.window.mouse.released(.LEFT)) return null;
    zhu.audio.playSound("assets/audio/Fantasy_UI (10).ogg");
    return event;
}

fn drawRow(pos: zhu.Vector2, row: Row, rowIndex: usize) void {
    const rect = zhu.Rect.init(pos.add(row.offset), row.size);
    const startIndex = zon.buttons.len + rowIndex * 2;

    drawIcon(rect, row.left, startIndex);
    drawIcon(rect, row.right, startIndex + 1);
    drawTextCenter(row.label, rect, zon.textNormal, .zero);
}

fn drawIcon(rowRect: zhu.Rect, icon: Icon, index: usize) void {
    const rect = zhu.Rect.init(rowRect.min.add(icon.offset), icon.size);
    const pressed = hover == index and buttonState == .pressed;
    const source = if (pressed) icon.pressed else icon.normal;
    zhu.batch.drawImage(image.sub(source), rect.min, .{ .size = rect.size });
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
