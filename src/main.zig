const std = @import("std");
const win32 = @import("win32");
const ui = win32.ui.windows_and_messaging;

pub fn main() !void {
    const caption = win32.zig.L("游戏编程");
    const message = win32.zig.L("Windows 游戏编程大师技巧");
    _ = ui.MessageBoxW(null, message, caption, ui.MB_OK);
}
