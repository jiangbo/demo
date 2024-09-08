const std = @import("std");
const win32 = @import("win32");

const ui = win32.ui.windows_and_messaging;
const gdi = win32.graphics.gdi;
const WINAPI = std.os.windows.WINAPI;

pub const WIDTH: u32 = 640;
pub const HEIGHT: u32 = 480;

pub var instance: std.os.windows.HINSTANCE = undefined;
pub var hander: win32.foundation.HWND = undefined;
pub var rand: std.Random = undefined;
pub var windowClosed: bool = false;

pub const Point = struct { x: u32, y: u32 };
pub var point: ?Point = null;
pub var key: ?usize = null;

pub fn mainWindowCallback(
    window: win32.foundation.HWND,
    message: u32,
    wParam: win32.foundation.WPARAM,
    lParam: win32.foundation.LPARAM,
) callconv(WINAPI) win32.foundation.LRESULT {
    switch (message) {
        ui.WM_CREATE => {
            std.log.info("WM_CREATE", .{});
        },
        ui.WM_LBUTTONDOWN => {
            const x: u32 = @intCast(lParam & 0xffff);
            const y: u32 = @intCast((lParam >> 16) & 0xffff);
            point = Point{ .x = x, .y = y };
        },

        ui.WM_KEYDOWN => key = wParam,
        ui.WM_DESTROY => {
            std.log.info("WM_DESTROY", .{});
            windowClosed = true;
            ui.PostQuitMessage(0);
        },
        else => return ui.DefWindowProc(window, message, wParam, lParam),
    }
    return 0;
}

const name = win32.zig.L("Direct3D 中的 2D 编程");

pub fn createWindow() void {
    std.log.info("wWinMain", .{});

    const h = win32.system.library_loader.GetModuleHandle(null).?;
    var windowClass = std.mem.zeroes(ui.WNDCLASSEX);
    const s = .{ .HREDRAW = 1, .VREDRAW = 1 };

    windowClass.cbSize = @sizeOf(ui.WNDCLASSEX);
    windowClass.style = s;
    windowClass.lpszClassName = name;
    windowClass.lpfnWndProc = mainWindowCallback;
    windowClass.hInstance = h;
    windowClass.hbrBackground = gdi.GetStockObject(gdi.BLACK_BRUSH);

    if (ui.RegisterClassEx(&windowClass) == 0) win32Panic();

    var style = ui.WS_OVERLAPPEDWINDOW;
    var rect = std.mem.zeroInit(win32.foundation.RECT, //
        .{ .right = WIDTH, .bottom = HEIGHT });
    _ = ui.AdjustWindowRectEx(&rect, style, 0, ui.WS_EX_LEFT);
    const width = rect.right - rect.left;
    const height = rect.bottom - rect.top;

    style.VISIBLE = 1;
    const window = ui.CreateWindowEx(ui.WS_EX_LEFT, name, name, style, //
        200, 200, width, height, null, null, h, null);

    instance = h;
    hander = window orelse win32Panic();

    const system = win32.system.system_information;
    var prng = std.rand.DefaultPrng.init(system.GetTickCount64());
    rand = prng.random();
}

pub fn update(gameUpdate: fn () void) void {
    var message: ui.MSG = undefined;
    while (true) {
        if (ui.PeekMessage(&message, null, 0, 0, ui.PM_REMOVE) > 0) {
            if (message.message == ui.WM_QUIT) break;
            _ = ui.TranslateMessage(&message);
            _ = ui.DispatchMessage(&message);
        }

        gameUpdate();
    }

    std.log.info("wWinMain end", .{});
}

pub fn win32Panic() noreturn {
    const err = win32.foundation.GetLastError();
    std.log.err("win32 panic code {}", .{@intFromEnum(err)});
    @panic(@tagName(err));
}
