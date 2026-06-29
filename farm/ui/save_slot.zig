const std = @import("std");
const zhu = @import("zhu");

const context = @import("../context.zig");
const save = @import("../save.zig");

const menus: []const zhu.widget.Menu = @import("../zon/menu.zon");

pub const Mode = enum {
    titleLoad,
    pauseSave,
    pauseLoad,
};

pub const Message = struct { text: []const u8, fail: bool };
pub const Result = union(enum) {
    close,
    message: Message,
    farmLoad: usize,
};
pub const TitleRequest = union(enum) { close, load: usize };

const SlotState = union(enum) {
    empty,
    invalid,
    valid: save.SlotSummary,
};

const backEvent: u8 = @intCast(save.slotCount);

pub var active: bool = false;

var mode: Mode = .titleLoad;
var slots: [save.slotCount]SlotState = @splat(.empty);
var confirmSlot: ?usize = null;
var confirmTitleBuffer: [40]u8 = undefined;
var disabledSlots: [save.slotCount]usize = undefined;
var disabledCount: usize = 0;
var closePause: bool = false;
var slotMenu: zhu.widget.Menu = menus[3];
var confirmMenu: zhu.widget.Menu = menus[4];

pub fn init() void {
    slotMenu.centerInWindow();
    confirmMenu.centerInWindow();
}

pub fn enter(next: Mode) void {
    active = true;
    mode = next;
    confirmSlot = null;
    closePause = false;
    refresh();
    rebuildDisabled();
    slotMenu.title.text = switch (mode) {
        .titleLoad, .pauseLoad => "Load Game",
        .pauseSave => "Save Game",
    };
    confirmMenu.title.text = "";
}

pub fn update(world: *zhu.ecs.World) ?Result {
    if (context.input.pressed(.pause)) {
        if (confirmSlot != null) {
            confirmSlot = null;
            return null;
        }

        active = false;
        return .close;
    }

    if (!active) {
        return null;
    }

    if (confirmSlot) |slot| {
        if (confirmMenu.update()) |event| {
            switch (event) {
                0 => { // 确认覆盖
                    confirmSlot = null;
                    return .{ .message = saveAndClose(world, slot) };
                },
                1 => confirmSlot = null, // 取消覆盖
                else => unreachable,
            }
        }
        return null;
    }

    if (slotMenu.update()) |e| {
        if (e == backEvent) {
            active = false;
            return .close;
        }
        return chooseSlot(world, e);
    }
    return null;
}

pub fn updateTitle() ?TitleRequest {
    if (context.input.pressed(.pause)) {
        active = false;
        return .close;
    }

    if (slotMenu.update()) |event| {
        if (event == backEvent) {
            active = false;
            return .close;
        }

        active = false;
        return .{ .load = event };
    }
    return null;
}

pub fn takeClosePause() bool {
    const result = closePause;
    closePause = false;
    return result;
}

pub fn draw() void {
    slotMenu.draw();
    for (0..save.slotCount) |index| drawSlot(index);
    if (confirmSlot != null) confirmMenu.draw();
}

fn rebuildDisabled() void {
    disabledCount = 0;
    for (0..save.slotCount) |index| {
        if (slotEnabled(index)) continue;
        disabledSlots[disabledCount] = index;
        disabledCount += 1;
    }
    slotMenu.disabled = disabledSlots[0..disabledCount];
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

fn chooseSlot(world: *zhu.ecs.World, slot: usize) ?Result {
    switch (mode) {
        .titleLoad => {
            active = false;
            return .{ .farmLoad = slot };
        },
        .pauseLoad => {
            save.loadSlot(world, slot) catch |err| {
                std.log.err("load slot {} failed: {}", .{ slot, err });
                active = false;
                return .{ .message = .{ .text = "读取失败", .fail = true } };
            };
            active = false;
            closePause = true;
            return .close;
        },
        .pauseSave => {
            if (slotHasFile(slot)) {
                confirmSlot = slot;
                confirmMenu.title.text = zhu.format(
                    &confirmTitleBuffer,
                    "Overwrite slot {d}?",
                    .{slot + 1},
                );
                return null;
            }
            return .{ .message = saveAndClose(world, slot) };
        },
    }
}

fn saveAndClose(world: *zhu.ecs.World, slot: usize) Message {
    save.saveSlot(world, slot) catch |err| {
        std.log.err("save slot {} failed: {}", .{ slot, err });
        active = false;
        return .{ .text = "保存失败", .fail = true };
    };
    active = false;
    return .{ .text = "保存成功", .fail = false };
}

fn drawSlot(index: usize) void {
    var buffer: [56]u8 = undefined;
    const label = switch (slots[index]) {
        .empty => zhu.format(&buffer, "Slot {d} Empty", .{index + 1}),
        .invalid => zhu.format(&buffer, "Slot {d} Invalid", .{index + 1}),
        .valid => |summary| zhu.format(&buffer, "Slot {d} Day {d}", .{
            index + 1,
            summary.day,
        }),
    };

    slotMenu.drawText(index, label);
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
