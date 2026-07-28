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

pub fn update() ?Request {
    const closeKey = input.anyReleased(&.{ .menu, .cancel });
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
