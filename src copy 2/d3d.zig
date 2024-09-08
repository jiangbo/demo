const std = @import("std");
const win32 = @import("win32");

const gdi = win32.graphics.gdi;
const ui = win32.ui.windows_and_messaging;
const d3d9 = win32.graphics.direct3d9;
const WINAPI = std.os.windows.WINAPI;
const failed = win32.zig.FAILED;

pub var point: ?isize = null;

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
        ui.WM_DESTROY => {
            std.log.info("WM_DESTROY", .{});
            ui.PostQuitMessage(0);
        },
        ui.WM_LBUTTONDOWN => point = lParam,
        else => return ui.DefWindowProc(window, message, wParam, lParam),
    }
    return 0;
}

const name = win32.zig.L("DirectX 9.0 3D游戏开发编程基础");

pub fn initD3D(width: i32, height: i32) *d3d9.IDirect3DDevice9 {
    //
    // Create the main application window.
    //
    var device: *d3d9.IDirect3DDevice9 = undefined;
    const h = win32.system.library_loader.GetModuleHandle(null).?;
    var windowClass = std.mem.zeroes(ui.WNDCLASSEX);

    windowClass.cbSize = @sizeOf(ui.WNDCLASSEX);
    windowClass.style = .{ .HREDRAW = 1, .VREDRAW = 1 };
    windowClass.lpszClassName = name;
    windowClass.lpfnWndProc = mainWindowCallback;
    windowClass.hInstance = h;
    windowClass.hbrBackground = gdi.GetStockObject(gdi.BLACK_BRUSH);

    if (ui.RegisterClassEx(&windowClass) == 0) win32Panic();
    var style = ui.WS_OVERLAPPEDWINDOW;
    style.VISIBLE = 1;
    const window = ui.CreateWindowEx(ui.WS_EX_LEFT, name, name, style, //
        200, 200, width, height, null, null, h, null).?;

    // Init D3D:
    // Step 1: Create the IDirect3D9 object.
    const d9 = d3d9.Direct3DCreate9(d3d9.D3D_SDK_VERSION).?;

    // Step 2: Check for hardware vp.
    // Step 3: Fill out the D3DPRESENT_PARAMETERS structure.

    const adapter = d3d9.D3DADAPTER_DEFAULT;
    var mode: d3d9.D3DDISPLAYMODE = undefined;
    var hr = d9.IDirect3D9_GetAdapterDisplayMode(adapter, &mode);
    if (failed(hr)) win32Panic();

    var params: d3d9.D3DPRESENT_PARAMETERS = undefined;

    //back buffer information
    params.BackBufferWidth = @intCast(width);
    params.BackBufferHeight = @intCast(height);
    params.BackBufferFormat = mode.Format;
    params.BackBufferCount = 1; //make one back buffer

    //multisampling
    params.MultiSampleType = .NONE;
    params.MultiSampleQuality = 0;

    //swap effect
    params.SwapEffect = .DISCARD;
    params.Windowed = win32.zig.TRUE; //windowed mode

    //destination window
    params.hDeviceWindow = window;

    //depth buffer information
    params.EnableAutoDepthStencil = win32.zig.TRUE;
    params.AutoDepthStencilFormat = .D24S8;

    //flags
    params.Flags = 0;

    //refresh rate and presentation interval
    params.FullScreen_RefreshRateInHz = d3d9.D3DPRESENT_RATE_DEFAULT;
    params.PresentationInterval = d3d9.D3DPRESENT_INTERVAL_DEFAULT;

    //attempt to create a HAL device
    hr = d9.IDirect3D9_CreateDevice(adapter, .HAL, window, //
        d3d9.D3DCREATE_HARDWARE_VERTEXPROCESSING, &params, @ptrCast(&device));
    if (failed(hr)) win32Panic();

    _ = d9.IUnknown_Release(); // done with d3d9 object
    return device;
}

var lastTime: u64 = 0;

pub fn enterMsgLoop(display: fn (f32) bool) void {
    var timer = std.time.Timer.start() catch unreachable;
    var message: ui.MSG = std.mem.zeroes(ui.MSG);
    while (true) {
        if (ui.PeekMessage(&message, null, 0, 0, ui.PM_REMOVE) > 0) {
            if (message.message == ui.WM_QUIT) break;
            _ = ui.TranslateMessage(&message);
            _ = ui.DispatchMessage(&message);
        } else {
            const delta: f32 = @floatFromInt(timer.lap());
            _ = display(delta / std.time.ns_per_s);
        }
    }
}

pub const Material = struct {
    pub const WHITE = .{ .r = 1, .g = 1, .b = 1, .a = 1.0 };
    pub const BLACK = .{ .r = 0, .g = 0, .b = 0, .a = 1.0 };
    pub const RED = .{ .r = 1, .g = 0, .b = 0, .a = 1.0 };
    pub const YELLOW = .{ .r = 1, .g = 1, .b = 0, .a = 1.0 };

    pub const white = init(WHITE, WHITE, WHITE, BLACK, 2.0);
    pub const black = init(BLACK, BLACK, BLACK, BLACK, 2.0);
    pub const red = init(RED, RED, RED, BLACK, 2.0);
    pub const yellow = init(YELLOW, YELLOW, YELLOW, BLACK, 2.0);

    const CV = d3d9.D3DCOLORVALUE;
    fn init(a: CV, d: CV, s: CV, e: CV, p: f32) d3d9.D3DMATERIAL9 {
        return d3d9.D3DMATERIAL9{
            .Ambient = a,
            .Diffuse = d,
            .Specular = s,
            .Emissive = e,
            .Power = p,
        };
    }
};

pub fn win32Panic() noreturn {
    const err = win32.foundation.GetLastError();
    std.log.err("win32 panic code {}", .{@intFromEnum(err)});
    @panic(@tagName(err));
}
