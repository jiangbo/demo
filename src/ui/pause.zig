const zhu = @import("zhu");

const input = @import("../zon.zig").input;

pub const Request = enum {
    status,
    item,
    load,
    save,
    about,
    exit,
    close,
};

var menu: zhu.widget.Menu = @import("pause.zon");

// 打开暂停菜单时将光标重置回第一项。
pub fn open() void {
    menu.reset();
}

pub fn update() ?Request {
    const closeKey = input.anyPressed(&.{ .menu, .cancel });
    if (closeKey or zhu.mouse.released(.RIGHT)) {
        return .close;
    }

    const event = menu.update(.{}) orelse return null;
    return @enumFromInt(event);
}

pub fn draw() void {
    menu.drawImage();
    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    menu.drawText();
}
