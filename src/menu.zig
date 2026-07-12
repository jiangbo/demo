const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const input = @import("input.zig");

pub const Menu = struct {
    background: bool = false,
    position: zhu.Vector2 = .zero,
    size: zhu.Vector2 = .zero,
    color: zhu.Color = .white,
    textColor: zhu.Color = .white,
    names: []const []const u8 = &.{},
    areas: []const zhu.Rect = &.{},
    events: []const u8 = &.{},
};

const State = struct {
    current: usize = 0,
};

const zon: []const Menu = @import("zon/menu.zon");
var states: [zon.len]State = [_]State{.{}} ** zon.len;
pub var active: u8 = 0;

pub fn current() *const Menu {
    return &zon[active];
}

pub fn update() ?u8 {
    const menu = zon[active];
    const state = &states[active];

    if (zhu.mouse.changed) {
        for (menu.areas, 0..) |area, i| {
            if (area.contains(window.mouse)) {
                state.current = i;
            }
        }
    }

    if (input.released(.down)) {
        state.current = (state.current + 1) % menu.names.len;
    }
    if (input.released(.up)) {
        state.current += menu.names.len;
        state.current = (state.current - 1) % menu.names.len;
    }

    var confirm = input.released(.confirm);
    if (input.mouseReleased(.LEFT)) {
        for (menu.areas, 0..) |area, i| {
            if (area.contains(window.mouse)) {
                state.current = i;
                confirm = true;
            }
        }
    }
    return if (confirm) menu.events[state.current] else null;
}

pub fn draw() void {
    const menu = zon[active];
    const state = &states[active];

    zhu.batch.drawRect(menu.areas[state.current], .{ .color = menu.color });
    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();

    for (menu.areas, menu.names) |area, name| {
        zhu.text.draw(name, area.min.addXY(5, -2), .{
            .color = menu.textColor,
        });
    }
}
