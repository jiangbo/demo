const std = @import("std");
const win32 = @import("win32");

const d3d9 = win32.graphics.direct3d9;
const ui = win32.ui.windows_and_messaging;

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

pub const BookEngine = struct {
    hwnd: win32.foundation.HWND,

    pub fn init(width: i32, height: i32) BookEngine {
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
            style, 200, 200, width, height, null, null, h, null).?;

        const time: u64 = @intCast(std.time.milliTimestamp());
        var prng = std.rand.DefaultPrng.init(time);
        rand = prng.random();

        return BookEngine{ .hwnd = window };
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

    pub fn init(width: i32, height: i32, hwnd: win32.foundation.HWND) Direct3D {
        var d3d = d3d9.Direct3DCreate9(d3d9.D3D_SDK_VERSION).?;

        const adapter = d3d9.D3DADAPTER_DEFAULT;
        var mode: d3d9.D3DDISPLAYMODE = undefined;
        win32Check(d3d.IDirect3D9_GetAdapterDisplayMode(adapter, &mode));

        var params = std.mem.zeroes(d3d9.D3DPRESENT_PARAMETERS);

        // 后备缓冲区信息
        params.BackBufferWidth = @intCast(width);
        params.BackBufferHeight = @intCast(height);
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

pub const Container = struct {
    gold: u32 = 0,
    keys: u32 = 0,
    potion: u32 = 0,
    armor: u32 = 0,
    weapon: u32 = 0,
    locked: bool = false,
    sector: u32 = 0,
    tile: u32 = 0,
};
pub var containers = std.BoundedArray(Container, 100).init(0);

pub const Door = struct {
    secret: bool = false,
    locked: bool = false,
    sector: u32 = 0,
    tile: u32 = 0,
};
pub var doors = std.BoundedArray(Door, 100).init(0);

pub const Person = struct {
    name: []u8 = &.{},
    canMove: bool = false,
    sector: u32 = 0,
    tile: u32 = 0,
};
pub var persons = std.BoundedArray(Person, 100).init(0);

pub const Player = struct {
    sector: u32 = 0,
    hitPoints: u32 = 0,
    maxHitPoints: u32 = 0,
    armor: u32 = 0,
    weapon: u32 = 0,
    gold: u32 = 0,
    keys: u32 = 0,
    potions: u32 = 0,
    experience: u32 = 0,
};
pub var player: Player = .{
    .gold = 25,
    .hitPoints = 10,
    .maxHitPoints = 10,
    .keys = 1,
};

pub fn win32Check(result: win32.foundation.HRESULT) void {
    if (win32.zig.SUCCEEDED(result)) return;
    const err = win32.foundation.GetLastError();
    std.log.err("win32 panic code 0X{0X}", .{@intFromEnum(err)});
    @panic(@tagName(err));
}
