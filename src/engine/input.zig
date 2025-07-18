const std = @import("std");
const sk = @import("sokol");
const math = @import("math.zig");

pub const KeyCode = sk.app.Keycode;

pub var lastKeyState: std.StaticBitSet(512) = .initEmpty();
pub var keyState: std.StaticBitSet(512) = .initEmpty();

pub var mousePosition: math.Vector = .zero;

pub var lastButtonState: std.StaticBitSet(3) = .initEmpty();
pub var buttonState: std.StaticBitSet(3) = .initEmpty();

pub fn event(ev: *const sk.app.Event) void {
    const keyCode: usize = @intCast(@intFromEnum(ev.key_code));
    const buttonCode: usize = @intCast(@intFromEnum(ev.mouse_button));
    switch (ev.type) {
        .KEY_DOWN => keyState.set(keyCode),
        .KEY_UP => keyState.unset(keyCode),
        .MOUSE_MOVE => mousePosition = .init(ev.mouse_x, ev.mouse_y),
        .MOUSE_DOWN => buttonState.set(buttonCode),
        .MOUSE_UP => buttonState.unset(buttonCode),
        .ICONIFIED, .UNFOCUSED => {
            keyState = .initEmpty();
            buttonState = .initEmpty();
        },
        else => {},
    }
}

pub fn isButtonPress(button: sk.app.Mousebutton) bool {
    const code: usize = @intCast(@intFromEnum(button));
    return !lastButtonState.isSet(code) and buttonState.isSet(code);
}

pub fn isButtonRelease(button: sk.app.Mousebutton) bool {
    const code: usize = @intCast(@intFromEnum(button));
    return lastButtonState.isSet(code) and !buttonState.isSet(code);
}

pub fn isAnyButtonRelease(buttons: []const sk.app.Mousebutton) bool {
    for (buttons) |button| if (isButtonRelease(button)) return true;
    return false;
}

pub fn isKeyDown(keyCode: KeyCode) bool {
    return keyState.isSet(@intCast(@intFromEnum(keyCode)));
}

pub fn isAnyKeyDown(keys: []const KeyCode) bool {
    for (keys) |key| if (isKeyDown(key)) return true;
    return false;
}

pub fn isKeyPress(keyCode: KeyCode) bool {
    const key: usize = @intCast(@intFromEnum(keyCode));
    return !lastKeyState.isSet(key) and keyState.isSet(key);
}

pub fn isAnyKeyPress(keys: []const KeyCode) bool {
    for (keys) |key| if (isKeyPress(key)) return true;
    return false;
}

pub fn isKeyRelease(keyCode: KeyCode) bool {
    const key: usize = @intCast(@intFromEnum(keyCode));
    return lastKeyState.isSet(key) and !keyState.isSet(key);
}

pub fn isAnyKeyRelease(keys: []const KeyCode) bool {
    for (keys) |key| if (isKeyRelease(key)) return true;
    return false;
}
