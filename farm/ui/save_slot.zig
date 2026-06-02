const std = @import("std");
const zhu = @import("zhu");

const context = @import("../context.zig");
const save = @import("../save.zig");

const NineOption = zhu.batch.NineOption;

pub const Mode = enum {
    titleLoad,
    pauseSave,
    pauseLoad,
};

const SlotState = union(enum) {
    empty,
    invalid,
    valid: save.SlotSummary,
};

const ButtonState = enum { normal, hover, pressed, disabled };

const gridColumns: usize = 2;
const panelSize: zhu.Vector2 = .{ .x = 360, .y = 298 };
const panelPadding: f32 = 16;
const headerHeight: f32 = 28;
const slotSize: zhu.Vector2 = .{ .x = 160, .y = 32 };
const slotSpacing: zhu.Vector2 = .{ .x = 8, .y = 8 };
const backSize: zhu.Vector2 = .{ .x = 160, .y = 32 };
const confirmSize: zhu.Vector2 = .{ .x = 280, .y = 120 };
const confirmButtonSize: zhu.Vector2 = .{ .x = 100, .y = 32 };

const buttonNormal: zhu.Rect = .{
    .min = .{ .x = 0, .y = 16 },
    .size = .{ .x = 48, .y = 16 },
};
const buttonPressed: zhu.Rect = .{
    .min = .{ .x = 0, .y = 32 },
    .size = .{ .x = 48, .y = 16 },
};
const buttonNine: NineOption = .{
    .topLeft = .{ .x = 3, .y = 5 },
    .bottomRight = .{ .x = 3, .y = 5 },
};

pub var active: bool = false;

var image: zhu.Image = undefined;
var mode: Mode = .titleLoad;
var slots: [save.slotCount]SlotState = @splat(.empty);
var hover: ?usize = null;
var buttonState: ButtonState = .normal;
var confirmSlot: ?usize = null;
var closePauseAfterLoad: bool = false;

pub fn init() void {
    image = zhu.getImage("farm-rpg/UI/button.png").?;
}

pub fn enter(next: Mode) void {
    active = true;
    mode = next;
    hover = null;
    buttonState = .normal;
    confirmSlot = null;
    closePauseAfterLoad = false;
    refresh();
}

pub fn takeClosePauseAfterLoad() bool {
    const result = closePauseAfterLoad;
    closePauseAfterLoad = false;
    return result;
}

pub fn cancel() void {
    if (confirmSlot != null) {
        confirmSlot = null;
        hover = null;
        return;
    }
    active = false;
    hover = null;
}

pub fn update(world: *zhu.ecs.World) void {
    if (confirmSlot) |slot| {
        updateConfirm(world, slot);
        return;
    }

    const mousePos = zhu.window.mousePosition;
    const panel = panelRect();

    for (0..save.slotCount) |index| {
        const rect = slotRect(panel, index);
        if (!rect.contains(mousePos)) continue;

        const enabled = slotEnabled(index);
        updateButton(index, if (enabled) .hover else .disabled);
        if (enabled and zhu.window.mouse.released(.LEFT)) {
            chooseSlot(world, index);
        }
        return;
    }

    const backIndex = save.slotCount;
    if (backRect(panel).contains(mousePos)) {
        updateButton(backIndex, .hover);
        if (zhu.window.mouse.released(.LEFT)) cancel();
        return;
    }

    hover = null;
    buttonState = .normal;
}

pub fn draw() void {
    const overlay = zhu.Rect.init(.zero, zhu.window.size);
    zhu.batch.drawRect(overlay, .{ .color = .gray(0, 0.45) });

    const panel = panelRect();
    zhu.batch.drawRect(panel, .{ .color = .gray(0, 0.72) });

    zhu.text.drawString(titleText(), panel.min.add(.xy(panelSize.x / 2, 22)), .{
        .alignment = .center,
    });

    for (0..save.slotCount) |index| drawSlot(panel, index);
    drawButton(backRect(panel), buttonVisual(save.slotCount, true), "Back");

    if (confirmSlot) |slot| drawConfirm(slot);
}

fn refresh() void {
    for (0..save.slotCount) |index| {
        const summary = save.readSlotSummary(index) catch |err| {
            std.log.warn("slot {} summary failed: {}", .{ index, err });
            slots[index] = .invalid;
            continue;
        };
        slots[index] = if (summary) |value| .{ .valid = value } else .empty;
    }
}

fn chooseSlot(world: *zhu.ecs.World, slot: usize) void {
    switch (mode) {
        .titleLoad => {
            active = false;
            context.scene.requestLoad(slot);
        },
        .pauseLoad => {
            save.loadSlot(world, slot) catch |err| {
                std.log.err("load slot {} failed: {}", .{ slot, err });
                active = false;
                return;
            };
            active = false;
            closePauseAfterLoad = true;
        },
        .pauseSave => {
            if (slotHasFile(slot)) {
                confirmSlot = slot;
                hover = null;
                return;
            }
            saveAndClose(world, slot);
        },
    }
}

fn saveAndClose(world: *zhu.ecs.World, slot: usize) void {
    save.saveSlot(world, slot) catch |err| {
        std.log.err("save slot {} failed: {}", .{ slot, err });
        active = false;
        return;
    };
    active = false;
}

fn updateConfirm(world: *zhu.ecs.World, slot: usize) void {
    const mousePos = zhu.window.mousePosition;
    const panel = confirmRect();

    const yesIndex = save.slotCount + 1;
    if (confirmYesRect(panel).contains(mousePos)) {
        updateButton(yesIndex, .hover);
        if (zhu.window.mouse.released(.LEFT)) {
            confirmSlot = null;
            saveAndClose(world, slot);
        }
        return;
    }

    const noIndex = save.slotCount + 2;
    if (confirmNoRect(panel).contains(mousePos)) {
        updateButton(noIndex, .hover);
        if (zhu.window.mouse.released(.LEFT)) cancel();
        return;
    }

    hover = null;
    buttonState = .normal;
}

fn drawConfirm(slot: usize) void {
    const overlay = zhu.Rect.init(.zero, zhu.window.size);
    zhu.batch.drawRect(overlay, .{ .color = .gray(0, 0.28) });

    const panel = confirmRect();
    zhu.batch.drawRect(panel, .{ .color = .gray(0, 0.86) });

    var buffer: [40]u8 = undefined;
    const text = zhu.format(&buffer, "Overwrite slot {d}?", .{slot + 1});
    zhu.text.drawString(text, panel.min.add(.xy(confirmSize.x / 2, 34)), .{
        .alignment = .center,
    });

    drawButton(confirmYesRect(panel), buttonVisual(save.slotCount + 1, true), "OK");
    drawButton(confirmNoRect(panel), buttonVisual(save.slotCount + 2, true), "Cancel");
}

fn drawSlot(panel: zhu.Rect, index: usize) void {
    const enabled = slotEnabled(index);
    const state = buttonVisual(index, enabled);

    var buffer: [56]u8 = undefined;
    const label = switch (slots[index]) {
        .empty => zhu.format(&buffer, "Slot {d} Empty", .{index + 1}),
        .invalid => zhu.format(&buffer, "Slot {d} Invalid", .{index + 1}),
        .valid => |summary| zhu.format(&buffer, "Slot {d} Day {d}", .{
            index + 1,
            summary.day,
        }),
    };

    drawButton(slotRect(panel, index), state, label);
}

fn drawButton(rect: zhu.Rect, state: ButtonState, label: []const u8) void {
    const source = switch (state) {
        .normal, .hover, .disabled => buttonNormal,
        .pressed => buttonPressed,
    };
    zhu.batch.drawNine(image.sub(source), rect, buttonNine);

    const color: zhu.Color = switch (state) {
        .normal => .white,
        .hover => .rgba(0.99, 0.91, 0.53, 1),
        .pressed => .gray(0.6, 1),
        .disabled => .gray(0.4, 1),
    };
    const offset: zhu.Vector2 = if (state == .pressed) .xy(0, 2) else .zero;
    zhu.text.drawString(label, rect.center().add(offset), .{
        .color = color,
        .alignment = .center,
    });
}

fn updateButton(index: usize, fallback: ButtonState) void {
    if (fallback == .disabled) {
        hover = index;
        buttonState = .disabled;
        return;
    }

    if (hover == null or hover.? != index) {
        zhu.audio.playSound("assets/audio/Fantasy_UI (1).ogg");
    }
    hover = index;
    buttonState = if (zhu.window.mouse.held(.LEFT)) .pressed else fallback;
}

fn buttonVisual(index: usize, enabled: bool) ButtonState {
    if (!enabled) return .disabled;
    return if (hover == index) buttonState else .normal;
}

fn slotEnabled(index: usize) bool {
    return switch (mode) {
        .pauseSave => true,
        .titleLoad, .pauseLoad => switch (slots[index]) {
            .valid => true,
            .empty, .invalid => false,
        },
    };
}

fn slotHasFile(index: usize) bool {
    return switch (slots[index]) {
        .empty => false,
        .invalid, .valid => true,
    };
}

fn titleText() []const u8 {
    return switch (mode) {
        .titleLoad, .pauseLoad => "Load Game",
        .pauseSave => "Save Game",
    };
}

fn panelRect() zhu.Rect {
    return .init(zhu.window.size.sub(panelSize).scale(0.5), panelSize);
}

fn slotRect(panel: zhu.Rect, index: usize) zhu.Rect {
    const col: f32 = @floatFromInt(index % gridColumns);
    const row: f32 = @floatFromInt(index / gridColumns);
    const start = panel.min.add(.xy(panelPadding, panelPadding + headerHeight));
    const offset = zhu.Vector2.xy(
        col * (slotSize.x + slotSpacing.x),
        row * (slotSize.y + slotSpacing.y),
    );
    return .init(start.add(offset), slotSize);
}

fn backRect(panel: zhu.Rect) zhu.Rect {
    const x = panel.min.x + (panelSize.x - backSize.x) / 2;
    const y = panel.min.y + panelSize.y - panelPadding - backSize.y;
    return .init(.xy(x, y), backSize);
}

fn confirmRect() zhu.Rect {
    return .init(zhu.window.size.sub(confirmSize).scale(0.5), confirmSize);
}

fn confirmYesRect(panel: zhu.Rect) zhu.Rect {
    const x = panel.min.x + 34;
    const y = panel.min.y + confirmSize.y - panelPadding - confirmButtonSize.y;
    return .init(.xy(x, y), confirmButtonSize);
}

fn confirmNoRect(panel: zhu.Rect) zhu.Rect {
    const x = panel.max().x - 34 - confirmButtonSize.x;
    const y = panel.min.y + confirmSize.y - panelPadding - confirmButtonSize.y;
    return .init(.xy(x, y), confirmButtonSize);
}
