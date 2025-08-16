const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const math = zhu.math;
const camera = zhu.camera;

pub const Menu = struct {
    background: bool = false,
    position: gfx.Vector = .zero,
    size: gfx.Vector = .zero,
    color: gfx.Color = .one,
    names: []const []const u8 = &.{},
    areas: []const gfx.Rect = &.{},
    events: []const u8 = &.{},
};

const State = struct {
    current: usize = 0,
};

var zon: []const Menu = @import("zon/menu.zon");
var states: [7]State = [_]State{.{}} ** 7;
pub var active: u8 = 0;

pub fn current() *const Menu {
    return &zon[active];
}

const parseZon = std.zon.parse.fromSlice;
pub fn reload(allocator: std.mem.Allocator) void {
    std.log.info("menu reload", .{});

    const content = window.readAll(allocator, "src/zon/menu.zon");
    defer allocator.free(content);
    const menu = parseZon([]Menu, allocator, content, null, .{});
    zon = menu catch @panic("error parse zon");
}

pub fn update() ?u8 {
    const menu = zon[active];
    const state = &states[active];

    if (window.mouseMoved) {
        for (menu.areas, 0..) |area, i| {
            if (area.contains(window.mousePosition)) {
                state.current = i;
            }
        }
    }

    if (window.isAnyKeyRelease(&.{ .DOWN, .S })) {
        state.current = (state.current + 1) % menu.names.len;
    }
    if (window.isAnyKeyRelease(&.{ .UP, .W })) {
        state.current += menu.names.len;
        state.current = (state.current - 1) % menu.names.len;
    }

    var confirm = window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER });
    if (window.isMouseRelease(.LEFT)) {
        for (menu.areas, 0..) |area, i| {
            if (area.contains(window.mousePosition)) {
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

    for (menu.areas, menu.names, 0..) |area, name, i| {
        if (i == state.current) {
            camera.drawRect(area, menu.color);
        }
        camera.drawText(name, area.min.addXY(5, -2));
    }
}
