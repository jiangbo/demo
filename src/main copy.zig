const std = @import("std");
const win32 = @import("win32");

const d3d10 = win32.graphics.direct3d10;
const ui = win32.ui.windows_and_messaging;

pub const UNICODE: bool = true;

const WIDTH = 800;
const HEIGHT = 600;

pub fn main() !void {
    _ = generateWindow();

    var message: ui.MSG = std.mem.zeroes(ui.MSG);

    while (true) {
        while (ui.PeekMessage(&message, null, 0, 0, ui.PM_REMOVE) > 0) {
            _ = ui.TranslateMessage(&message);
            _ = ui.DispatchMessage(&message);
        }
        if (message.message == ui.WM_QUIT) break;
    }
}

pub fn windowCallback(
    w: win32.foundation.HWND,
    message: u32,
    wParam: win32.foundation.WPARAM,
    lParam: win32.foundation.LPARAM,
) callconv(std.os.windows.WINAPI) win32.foundation.LRESULT {
    switch (message) {
        ui.WM_DESTROY => {
            std.log.info("WM_DESTROY", .{});
            ui.PostQuitMessage(0);
        },
        else => {},
    }
    return ui.DefWindowProc(w, message, wParam, lParam);
}

fn generateWindow() win32.foundation.HWND {
    const handle = win32.system.library_loader.GetModuleHandle(null).?;

    var windowClass = std.mem.zeroes(ui.WNDCLASSEX);
    const className = win32.zig.L("DirectX10");
    windowClass.cbSize = @sizeOf(ui.WNDCLASSEX);
    windowClass.style = .{ .HREDRAW = 1, .VREDRAW = 1 };
    windowClass.lpszClassName = className;
    windowClass.lpfnWndProc = windowCallback;
    windowClass.hInstance = handle;
    win32Check(ui.RegisterClassEx(&windowClass));

    var style = ui.WS_OVERLAPPEDWINDOW;
    style.VISIBLE = 1;
    const name = win32.zig.L("DirectX10 学习");
    const window = ui.CreateWindowEx(ui.WS_EX_LEFT, className, name, //
        style, 200, 200, WIDTH, HEIGHT, null, null, handle, null).?;

    return window;
}

pub fn win32Check(result: win32.foundation.HRESULT) void {
    if (win32.zig.SUCCEEDED(result)) return;
    @panic(@tagName(win32.foundation.GetLastError()));
}
