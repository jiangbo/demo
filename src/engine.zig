const std = @import("std");
const win32 = @import("win32");
const file = @import("engine/file.zig");
const constants = @import("engine/constants.zig");
const objects = @import("engine/objects.zig");

const d3d9 = win32.graphics.direct3d9;
const ui = win32.ui.windows_and_messaging;
const LocationEnum = constants.LocationEnum;

pub fn windowCallback(
    w: win32.foundation.HWND,
    message: u32,
    wParam: win32.foundation.WPARAM,
    lParam: win32.foundation.LPARAM,
) callconv(std.os.windows.WINAPI) win32.foundation.LRESULT {
    switch (message) {
        ui.WM_CREATE => {
            std.log.info("WM_CREATE", .{});
        },
        ui.WM_DESTROY => {
            std.log.info("WM_DESTROY", .{});
            ui.PostQuitMessage(0);
        },
        else => return ui.DefWindowProc(w, message, wParam, lParam),
    }
    return 0;
}

const WIDTH = 640;
const HEIGHT = 480;

pub const BookEngine = struct {
    hwnd: win32.foundation.HWND,
    direct3D: Direct3D,
    map: objects.Map = undefined,

    pub fn init() BookEngine {
        const h = win32.system.library_loader.GetModuleHandle(null).?;
        var windowClass = std.mem.zeroes(ui.WNDCLASSEX);

        const className = win32.zig.L("TeachYourselfDirectX9");
        windowClass.cbSize = @sizeOf(ui.WNDCLASSEX);
        windowClass.style = .{ .HREDRAW = 1, .VREDRAW = 1 };
        windowClass.lpszClassName = className;
        windowClass.lpfnWndProc = windowCallback;
        windowClass.hInstance = h;

        win32Check(ui.RegisterClassEx(&windowClass));
        var style = ui.WS_OVERLAPPEDWINDOW;
        style.VISIBLE = 1;
        const name = win32.zig.L("2D 游戏开发");
        const window = ui.CreateWindowEx(ui.WS_EX_LEFT, className, name, //
            style, 200, 200, WIDTH, HEIGHT, null, null, h, null).?;

        const time: u64 = @intCast(std.time.milliTimestamp());
        var prng = std.rand.DefaultPrng.init(time);
        rand = prng.random();

        return .{ .hwnd = window, .direct3D = Direct3D.init(window) };
    }

    pub fn deinit(self: BookEngine) void {
        self.direct3D.deinit();
        _ = ui.DestroyWindow(self.hwnd);
    }

    fn openMapFiles(self: *BookEngine) void {
        _ = file.readMapFile(self.firstMap, &self.sectors);
        file.readPeopleFile(self.firstMap);
        // file.readContainerFile(self.firstMap);
        // file.readDoorFile(self.firstMap);
    }

    pub fn processGame() void {}
    pub fn handleKeys(wParam: std.os.windows.WPARAM) void {
        _ = wParam;
    }
};

pub var rand: std.Random = undefined;

pub const Direct3D = struct {
    hwnd: win32.foundation.HWND,
    d3d: *d3d9.IDirect3D9,
    device: *d3d9.IDirect3DDevice9,
    backBuffer: *d3d9.IDirect3DSurface9,

    pub fn init(hwnd: win32.foundation.HWND) Direct3D {
        var d3d = d3d9.Direct3DCreate9(d3d9.D3D_SDK_VERSION).?;

        const adapter = d3d9.D3DADAPTER_DEFAULT;
        var mode: d3d9.D3DDISPLAYMODE = undefined;
        win32Check(d3d.IDirect3D9_GetAdapterDisplayMode(adapter, &mode));

        var params = std.mem.zeroes(d3d9.D3DPRESENT_PARAMETERS);

        // 后备缓冲区信息
        params.BackBufferWidth = @intCast(WIDTH);
        params.BackBufferHeight = @intCast(HEIGHT);
        params.BackBufferFormat = mode.Format;
        params.BackBufferCount = 1; // 使用一个后备缓冲

        // 交换效果
        params.SwapEffect = .DISCARD;
        params.Windowed = win32.zig.TRUE; // 窗口模式

        // 渲染的目的窗口
        params.hDeviceWindow = hwnd;

        // 创建设备
        var device: *d3d9.IDirect3DDevice9 = undefined;
        win32Check(d3d.IDirect3D9_CreateDevice(adapter, .HAL, hwnd, //
            d3d9.D3DCREATE_HARDWARE_VERTEXPROCESSING, &params, @ptrCast(&device)));

        // 获取后备缓冲
        var back: *d3d9.IDirect3DSurface9 = undefined;
        win32Check(device.IDirect3DDevice9_GetBackBuffer(0, 0, .MONO, @ptrCast(&back)));

        return Direct3D{
            .hwnd = hwnd,
            .d3d = d3d,
            .device = device,
            .backBuffer = back,
        };
    }

    pub fn deinit(self: Direct3D) void {
        _ = self.backBuffer.IUnknown_Release();
        _ = self.device.IUnknown_Release();
        _ = self.d3d.IUnknown_Release();
    }
};

pub fn win32Check(result: win32.foundation.HRESULT) void {
    if (win32.zig.SUCCEEDED(result)) return;
    const err = win32.foundation.GetLastError();
    std.log.err("win32 panic code 0X{0X}", .{@intFromEnum(err)});
    @panic(@tagName(err));
}
