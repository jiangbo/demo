const std = @import("std");
const win32 = @import("win32");

const d3d9 = win32.graphics.direct3d9;
const ui = win32.ui.windows_and_messaging;

pub const GraphicsDevice = struct {
    device: *d3d9.IDirect3DDevice9,
    direct3d: *d3d9.IDirect3D9,

    pub fn init(window: win32.foundation.HWND) GraphicsDevice {
        var d3d = d3d9.Direct3DCreate9(d3d9.D3D_SDK_VERSION).?;

        var params = std.mem.zeroes(d3d9.D3DPRESENT_PARAMETERS);
        params.Windowed = win32.zig.TRUE;
        params.SwapEffect = .DISCARD;
        params.hDeviceWindow = window;

        // 创建设备
        var device: *d3d9.IDirect3DDevice9 = undefined;
        win32Check(d3d.CreateDevice(d3d9.D3DADAPTER_DEFAULT, .HAL, window, //
            d3d9.D3DCREATE_HARDWARE_VERTEXPROCESSING, &params, @ptrCast(&device)));
        return .{ .device = device, .direct3d = d3d };
    }

    pub fn clear(self: *GraphicsDevice, color: u32) void {
        const target = win32.system.system_services.D3DCLEAR_TARGET;
        win32Check(self.device.Clear(0, null, target, color, 1.0, 0));
    }

    pub fn begin(self: *GraphicsDevice) void {
        win32Check(self.device.BeginScene());
    }

    pub fn end(self: *GraphicsDevice) void {
        win32Check(self.device.EndScene());
    }

    pub fn Present(self: *GraphicsDevice) void {
        win32Check(self.device.Present(null, null, null, null));
    }

    pub fn deinit(self: *GraphicsDevice) void {
        _ = self.device.IUnknown.Release();
        _ = self.direct3d.IUnknown.Release();
    }
};

pub fn win32Check(result: win32.foundation.HRESULT) void {
    if (win32.zig.SUCCEEDED(result)) return;
    @panic(@tagName(win32.foundation.GetLastError()));
}
