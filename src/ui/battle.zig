const zhu = @import("zhu");

pub const Request = enum {
    attack,
    status,
    item,
    escape,
};

var menu: zhu.widget.Menu = @import("battle.zon");

// 新战斗默认选择攻击。
pub fn reset() void {
    menu.reset();
    menu.selected = 0;
}

pub fn update() ?Request {
    const event = menu.update(.{}) orelse return null;
    return @enumFromInt(event);
}

pub fn draw() void {
    menu.drawImage();
    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    menu.drawText();
}
