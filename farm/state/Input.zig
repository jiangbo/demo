const std = @import("std");
const zhu = @import("zhu");

pub const Command = enum {
    moveLeft,
    moveRight,
    moveUp,
    moveDown,
    pause,
    interact,
    inventory,
    hotbar,
    hotbar1,
    hotbar2,
    hotbar3,
    hotbar4,
    hotbar5,
    hotbar6,
    hotbar7,
    hotbar8,
    hotbar9,
    hotbar10,
};

const Entry = struct { type: Command, value: []const zhu.key.Code };
const zon: []const Entry = @import("input.zon");
const keys = zhu.enums.fromEntries(Entry, zon);
const Mouse = zhu.mouse.Button;

mouseCaptured: bool = false,

pub fn held(_: *const @This(), command: Command) bool {
    return zhu.key.anyHeld(keys.get(command));
}

pub fn pressed(_: *const @This(), command: Command) bool {
    return zhu.key.anyPressed(keys.get(command));
}

pub fn released(_: *const @This(), command: Command) bool {
    return zhu.key.anyReleased(keys.get(command));
}

pub fn mouseHeld(self: *const @This(), button: Mouse) bool {
    if (self.mouseCaptured) return false;
    return zhu.mouse.held(button);
}

pub fn mousePressed(self: *const @This(), button: Mouse) bool {
    if (self.mouseCaptured) return false;
    return zhu.mouse.pressed(button);
}

pub fn mouseReleased(self: *const @This(), button: Mouse) bool {
    if (self.mouseCaptured) return false;
    return zhu.mouse.released(button);
}

pub fn hotbarPressed(self: *const @This()) ?u8 {
    const first: usize = @intFromEnum(Command.hotbar1);
    const last: usize = @intFromEnum(Command.hotbar10);
    for (first..last + 1) |value| {
        const command: Command = @enumFromInt(value);
        if (self.pressed(command)) return @intCast(value - first);
    }
    return null;
}
