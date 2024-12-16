const std = @import("std");
const win32 = @import("win32");
const engine = @import("engine.zig");
const d3dx9 = @import("d3dx9.zig");

const d3d9 = win32.graphics.direct3d9;
const ui = win32.ui.windows_and_messaging;
const win32Check = engine.win32Check;

pub const UNICODE: bool = true;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var bookEngine = engine.BookEngine.init(gpa.allocator());
    defer bookEngine.deinit();

    bookEngine.openMapFiles("maps/FirstTown.json");

    var message: ui.MSG = std.mem.zeroes(ui.MSG);
    while (true) {
        if (ui.PeekMessage(&message, null, 0, 0, ui.PM_REMOVE) > 0) {
            if (message.message == ui.WM_QUIT) break;
            _ = ui.TranslateMessage(&message);
            _ = ui.DispatchMessage(&message);
        }
    }
}
