const zhu = @import("zhu");

pub const Command = enum {
    left,
    right,
    up,
    down,
    confirm,
    cancel,
    menu,
    useItem,
    dropItem,
    buyItem,
    help,
    debug,
};

const Entry = struct {
    type: Command,
    value: []const zhu.key.Code,
};

const zon: []const Entry = @import("zon/input.zon");
const keys = zhu.enums.fromEntries(Entry, zon);
const Mouse = zhu.mouse.Button;

pub fn held(command: Command) bool {
    return zhu.key.anyHeld(keys.get(command));
}

pub fn pressed(command: Command) bool {
    return zhu.key.anyPressed(keys.get(command));
}

pub fn released(command: Command) bool {
    return zhu.key.anyReleased(keys.get(command));
}

pub fn mouseHeld(button: Mouse) bool {
    return zhu.mouse.held(button);
}

pub fn mousePressed(button: Mouse) bool {
    return zhu.mouse.pressed(button);
}

pub fn mouseReleased(button: Mouse) bool {
    return zhu.mouse.released(button);
}
