const std = @import("std");
const zhu = @import("zhu");

const store = @import("../save.zig");
const menus: []const zhu.widget.Menu = @import("save.zon");

pub const Mode = enum { load, save };
pub const Request = union(enum) { close, save: u8, load: u8 };
pub const Slot = store.Slot;

var mode: Mode = .load;
var slots: []const Slot = &.{};
var confirmSlot: ?u8 = null;
var confirmTitleBuffer: [40]u8 = undefined;
var disabledBuffer: [menus[0].buttons.len]usize = undefined;
var disabled: std.ArrayList(usize) = .initBuffer(&disabledBuffer);
var slotMenu: zhu.widget.Menu = menus[0];
var confirmMenu: zhu.widget.Menu = menus[1];

pub fn init(slotStates: []const Slot) void {
    slots = slotStates;
    slotMenu.centerInWindow();
    confirmMenu.centerInWindow();
}

pub fn open(next: Mode) void {
    disabled.clearRetainingCapacity();
    for (0..slots.len) |index| {
        if (slotEnabled(index)) continue;
        disabled.appendAssumeCapacity(index);
    }
    slotMenu.disabled = disabled.items;

    mode = next;
    confirmSlot = null;
    slotMenu.title.text = switch (mode) {
        .load => "Load Game",
        .save => "Save Game",
    };
    confirmMenu.title.text = "";
}

pub fn update() ?Request {
    if (confirmSlot) |slot| {
        if (confirmMenu.update(.{})) |event| {
            switch (event) {
                0 => {
                    confirmSlot = null;
                    return .{ .save = slot };
                },
                1 => confirmSlot = null,
                else => unreachable,
            }
        }
        return null;
    }

    if (slotMenu.update(.{})) |event| {
        const backEvent: u8 = @intCast(slots.len);
        if (event == backEvent) {
            return .close;
        }
        return chooseSlot(event);
    }
    return null;
}

pub fn draw() void {
    slotMenu.draw();
    for (0..slots.len) |index| drawSlot(index);
    if (confirmSlot != null) confirmMenu.draw();
}

fn chooseSlot(slot: usize) ?Request {
    switch (mode) {
        .load => return .{ .load = @intCast(slot) },
        .save => {
            if (slotHasFile(slot)) {
                confirmSlot = @intCast(slot);
                confirmMenu.title.text = zhu.format(
                    &confirmTitleBuffer,
                    "Overwrite slot {d}?",
                    .{slot + 1},
                );
                return null;
            }
            return .{ .save = @intCast(slot) };
        },
    }
}

fn drawSlot(index: usize) void {
    var buffer: [56]u8 = undefined;
    const label = switch (slots[index]) {
        .empty => zhu.format(&buffer, "Slot {d} Empty", .{index + 1}),
        .invalid => zhu.format(&buffer, "Slot {d} Invalid", .{
            index + 1,
        }),
        .valid => |summary| zhu.format(&buffer, "Slot {d} Day {d}", .{
            index + 1,
            summary.day,
        }),
    };

    slotMenu.drawText(index, label);
}

fn slotEnabled(index: usize) bool {
    return switch (mode) {
        .save => true,
        .load => switch (slots[index]) {
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
