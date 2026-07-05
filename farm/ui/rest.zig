const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");

pub const Request = enum { close };

const MenuEvent = enum(u8) { minus, plus, ok, cancel };

pub var hours: u8 = 8;
var menu: zhu.widget.Menu = @import("rest.zon");

pub fn init() void {
    menu.centerInWindow();
}

pub fn update(world: *zhu.ecs.World) ?Request {
    const event = menu.update(.{}) orelse return null;
    switch (@as(MenuEvent, @enumFromInt(event))) {
        .minus => hours -= 1,
        .plus => hours += 1,
        .ok => {
            world.addEvent(component.event.Rest{ .hours = hours });
            return .close;
        },
        .cancel => return .close,
    }
    hours = std.math.clamp(hours, 1, 24);
    return null;
}

pub fn draw() void {
    menu.draw();

    const position = menu.position.add(.xy(140, 82));
    zhu.text.drawFmt("{d}h", .{hours}, position, .{
        .anchor = .center,
    });
}
