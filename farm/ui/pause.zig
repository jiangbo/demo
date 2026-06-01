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
    imageId: ImageId,
    size: zhu.Vector2,
    overlayColor: zhu.Color,
    panelColor: zhu.Color,
    hoverSound: [:0]const u8,
    clickSound: [:0]const u8,
    textNormal: zhu.Color,
    textHover: zhu.Color,
    textPressed: zhu.Color,
    textHoverOffset: zhu.Vector2,
    textPressedOffset: zhu.Vector2,
    buttons: []const Button,
    rows: []const Row,
};

const zon: Config = @import("../zon/pause.zon");

pub var active: bool = false;

var image: zhu.Image = undefined;
var hoverIndex: ?usize = null;
var buttonState: ButtonState = .normal;

pub fn init() void {
    image = zhu.assets.getImage(zon.imageId).?;
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
        hoverIndex = null;
        buttonState = .normal;
    }
    return null;
}

pub fn draw() void {
    const previousMode = zhu.camera.mode;
    zhu.camera.mode = .window;
    defer zhu.camera.mode = previousMode;

    const overlay = zhu.Rect.init(.zero, zhu.window.size);
    zhu.batch.drawRect(overlay, .{ .color = zon.overlayColor });

    const panel = zhu.Rect.init(zhu.window.size.sub(zon.size).scale(0.5), zon.size);
    zhu.batch.drawRect(panel, .{ .color = zon.panelColor });

    for (zon.buttons, 0..) |button, index| drawButton(panel, button, index);
    for (zon.rows, 0..) |row, index| drawRow(panel, row, index);
}

fn updateButton(index: usize, press: bool, event: Event) ?Event {
    if (hoverIndex == null or hoverIndex.? != index) {
        zhu.audio.playSound(zon.hoverSound);
    }
    hoverIndex = index;
    buttonState = if (press) .pressed else .hover;

    if (!zhu.window.mouse.released(.LEFT)) return null;
    zhu.audio.playSound(zon.clickSound);
    return event;
}

fn drawButton(panel: zhu.Rect, button: Button, index: usize) void {
    const rect = zhu.Rect.init(panel.min.add(button.offset), button.size);
    const state = if (hoverIndex == index) buttonState else .normal;
    const source = switch (state) {
        .normal => button.normal,
        .hover => button.hover,
        .pressed => button.pressed,
    };

    zhu.batch.drawNine(image.sub(source), rect, button.nine);

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

fn drawRow(panel: zhu.Rect, row: Row, rowIndex: usize) void {
    const rect = zhu.Rect.init(panel.min.add(row.offset), row.size);
    const startIndex = zon.buttons.len + rowIndex * 2;

    drawIcon(rect, row.left, startIndex);
    drawIcon(rect, row.right, startIndex + 1);
    drawTextCenter(row.label, rect, zon.textNormal, .zero);
}

fn drawIcon(rowRect: zhu.Rect, icon: Icon, index: usize) void {
    const rect = zhu.Rect.init(rowRect.min.add(icon.offset), icon.size);
    const pressed = hoverIndex == index and buttonState == .pressed;
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
