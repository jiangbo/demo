const zhu = @import("zhu");

const storage = @import("../storage.zig");

pub const Mode = enum { load, save };
pub const Request = union(enum) { close, load: u8, save: u8 };

var mode: Mode = .load;
var menu: zhu.widget.Menu = @import("save.zon");

// 打开指定用途的存档槽菜单。
pub fn open(next: Mode) void {
    mode = next;
    menu.reset();
}

pub fn update() ?Request {
    const event = menu.update(.{}) orelse return null;
    if (event == 6) return .close;

    const slot: u8 = @intCast(event);
    if (mode == .load and !storage.exists(slot)) return null;
    return switch (mode) {
        .load => .{ .load = slot },
        .save => .{ .save = slot },
    };
}

pub fn draw() void {
    menu.drawImage();
    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    menu.drawText();
}
