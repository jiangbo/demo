const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");

pub var position: math.Vector = .zero;
pub var leftKeyDown: bool = false;

pub fn event(ev: *const window.Event) void {
    if (ev.type == .MOUSE_MOVE) {
        position = .init(ev.mouse_x, ev.mouse_y);
    }

    if (ev.mouse_button == .LEFT) {
        if (ev.type == .MOUSE_DOWN) {
            leftKeyDown = true;
            switch (math.randU8(1, 3)) {
                1 => audio.playSound("assets/click_1.ogg"),
                2 => audio.playSound("assets/click_2.ogg"),
                3 => audio.playSound("assets/click_3.ogg"),
                else => unreachable,
            }
        }
        if (ev.type == .MOUSE_UP) leftKeyDown = false;
    }
}

pub fn render() void {
    if (leftKeyDown) {
        gfx.draw(gfx.loadTexture("assets/cursor_down.png"), position);
    } else {
        gfx.draw(gfx.loadTexture("assets/cursor_idle.png"), position);
    }
}
