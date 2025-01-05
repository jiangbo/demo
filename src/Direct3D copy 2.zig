const std = @import("std");
const win32 = @import("win32");

const dxgi = win32.graphics.dxgi;
const d11 = win32.graphics.direct3d11;

device: *d11.ID3D11Device = undefined,
swapChain: *dxgi.IDXGISwapChain = undefined,
deviceContext: *d11.ID3D11DeviceContext = undefined,
targetView: *d11.ID3D11RenderTargetView = undefined,

pub fn initialize(self: *@This(), w: u16, h: u16, window: ?win32.foundation.HWND) void {
    var desc = std.mem.zeroes(dxgi.DXGI_SWAP_CHAIN_DESC);
    desc.BufferDesc.Width = w;
    desc.BufferDesc.Height = h;
    desc.BufferDesc.RefreshRate = .{ .Numerator = 6000, .Denominator = 100 };
    desc.BufferDesc.Format = .R8G8B8A8_UNORM;

    desc.SampleDesc = .{ .Count = 1, .Quality = 0 };
    desc.BufferUsage = dxgi.DXGI_USAGE_RENDER_TARGET_OUTPUT;
    desc.BufferCount = 1;
    desc.OutputWindow = window;
    desc.Windowed = win32.zig.TRUE;
    desc.SwapEffect = .DISCARD;

    const flags = d11.D3D11_CREATE_DEVICE_DEBUG;
    win32Check(d11.D3D11CreateDeviceAndSwapChain(
        null,
        .HARDWARE,
        null,
        flags, //
        null,
        0,
        d11.D3D11_SDK_VERSION,
        &desc,
        @ptrCast(&self.swapChain),
        @ptrCast(&self.device),
        null,
        @ptrCast(&self.deviceContext),
    ));

    var back: *d11.ID3D11Texture2D = undefined;
    win32Check(self.swapChain.GetBuffer(0, d11.IID_ID3D11Texture2D, @ptrCast(&back)));
    defer _ = back.IUnknown.Release();

    win32Check(self.device.CreateRenderTargetView(@ptrCast(back), null, &self.targetView));

    self.deviceContext.OMSetRenderTargets(1, @ptrCast(&self.targetView), null);
}

pub fn beginScene(self: *@This(), red: f32, green: f32, blue: f32, alpha: f32) void {
    const color = [_]f32{ 0, 1, 1, 1 };
    _ = red;
    _ = green;
    _ = blue;
    _ = alpha;
    self.deviceContext.ClearRenderTargetView(self.targetView, @ptrCast(&color));
}

pub fn endScene(self: *@This()) void {
    win32Check(self.swapChain.Present(1, 0));
}

pub fn shutdown(self: *@This()) void {
    _ = self.targetView.IUnknown.Release();
    _ = self.swapChain.IUnknown.Release();
    _ = self.device.IUnknown.Release();
}

fn win32Check(result: win32.foundation.HRESULT) void {
    if (win32.zig.SUCCEEDED(result)) return;
    @panic(@tagName(win32.foundation.GetLastError()));
}
