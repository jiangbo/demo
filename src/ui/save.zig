const zhu = @import("zhu");

pub const Mode = enum { load, save };
pub const Request = union(enum) { close, load: u8, save: u8 };

var mode: Mode = .load;
var menu: zhu.widget.Menu = @import("save.zon");

// 打开指定用途的存档槽菜单。
pub fn open(next: Mode) void {
    mode = next;
}

pub fn update() ?Request {
    const event = menu.update(.{}) orelse return null;
    if (event == 5) return .close;

    const index: u8 = @intCast(event + 3);
    return switch (mode) {
        .load => .{ .load = index },
        .save => .{ .save = index },
    };
}

pub fn draw() void {
    menu.drawImage();
    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    menu.drawText();
}
