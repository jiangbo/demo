const std = @import("std");
const win32 = @import("win32");

const dxgi = win32.graphics.dxgi;
const d10 = win32.graphics.direct3d10;

device: *d10.ID3D10Device = undefined,
swapChain: *dxgi.IDXGISwapChain = undefined,
targetView: *d10.ID3D10RenderTargetView = undefined,
depthStencilBuffer: *d10.ID3D10Texture2D = undefined,
depthStencilState: *d10.ID3D10DepthStencilState = undefined,
depthStencilView: *d10.ID3D10DepthStencilView = undefined,

pub fn initialize(self: *@This(), w: u16, h: u16, window: ?win32.foundation.HWND) void {
    var desc = std.mem.zeroes(dxgi.DXGI_SWAP_CHAIN_DESC);
    desc.BufferDesc.Width = w;
    desc.BufferDesc.Height = h;
    desc.BufferDesc.RefreshRate = .{ .Numerator = 60, .Denominator = 1 };
    desc.BufferDesc.Format = .R8G8B8A8_UNORM;

    desc.SampleDesc = .{ .Count = 1, .Quality = 0 };
    desc.BufferUsage = dxgi.DXGI_USAGE_RENDER_TARGET_OUTPUT;
    desc.BufferCount = 1;
    desc.OutputWindow = window;
    desc.Windowed = win32.zig.TRUE;

    const flags: u16 = @intFromEnum(d10.D3D10_CREATE_DEVICE_DEBUG);
    win32Check(d10.D3D10CreateDeviceAndSwapChain(null, .HARDWARE, null, flags, //
        d10.D3D10_SDK_VERSION, &desc, @ptrCast(&self.swapChain), @ptrCast(&self.device)));

    var back: *d10.ID3D10Texture2D = undefined;
    win32Check(self.swapChain.GetBuffer(0, d10.IID_ID3D10Texture2D, @ptrCast(&back)));
    defer _ = back.IUnknown.Release();

    const target: *?*d10.ID3D10RenderTargetView = @ptrCast(&self.targetView);
    win32Check(self.device.CreateRenderTargetView(@ptrCast(back), null, target));

    self.device.OMSetRenderTargets(1, @ptrCast(&self.targetView), null);

    // 深度
    // var depthBufferDesc = std.mem.zeroes(d10.D3D10_TEXTURE2D_DESC);

    // depthBufferDesc.Width = w;
    // depthBufferDesc.Height = h;
    // depthBufferDesc.MipLevels = 1;
    // depthBufferDesc.ArraySize = 1;
    // depthBufferDesc.Format = .D24_UNORM_S8_UINT;
    // depthBufferDesc.SampleDesc = .{ .Count = 1, .Quality = 0 };
    // depthBufferDesc.BindFlags = @intFromEnum(d10.D3D10_BIND_DEPTH_STENCIL);

    // win32Check(self.device.CreateTexture2D(@ptrCast(&depthBufferDesc), null, @ptrCast(&self.depthStencilBuffer)));

    // var depthStencilDesc = std.mem.zeroes(d10.D3D10_DEPTH_STENCIL_DESC);

    // // Set up the description of the stencil state.
    // depthStencilDesc.DepthEnable = win32.zig.TRUE;
    // depthStencilDesc.DepthWriteMask = .ALL;
    // depthStencilDesc.DepthFunc = d10.D3D10_COMPARISON_LESS;

    // depthStencilDesc.StencilEnable = win32.zig.TRUE;
    // depthStencilDesc.StencilReadMask = 0xFF;
    // depthStencilDesc.StencilWriteMask = 0xFF;

    // // Stencil operations if pixel is front-facing.
    // depthStencilDesc.FrontFace.StencilFailOp = .KEEP;
    // depthStencilDesc.FrontFace.StencilDepthFailOp = .INCR;
    // depthStencilDesc.FrontFace.StencilPassOp = .KEEP;
    // depthStencilDesc.FrontFace.StencilFunc = .ALWAYS;

    // // Stencil operations if pixel is back-facing.
    // depthStencilDesc.BackFace.StencilFailOp = .KEEP;
    // depthStencilDesc.BackFace.StencilDepthFailOp = .DECR;
    // depthStencilDesc.BackFace.StencilPassOp = .KEEP;
    // depthStencilDesc.BackFace.StencilFunc = .ALWAYS;

    // win32Check(self.device.CreateDepthStencilState(&depthStencilDesc, @ptrCast(&self.depthStencilState)));

    // self.device.OMSetDepthStencilState(self.depthStencilState, 1);

    // var depthStencilViewDesc = std.mem.zeroes(d10.D3D10_DEPTH_STENCIL_VIEW_DESC);

    // // Set up the depth stencil view description.
    // depthStencilViewDesc.Format = .D24_UNORM_S8_UINT;
    // depthStencilViewDesc.ViewDimension = d10.D3D10_DSV_DIMENSION_TEXTURE2D;
    // depthStencilViewDesc.Anonymous.Texture2D.MipSlice = 0;

    // win32Check(self.device.CreateDepthStencilView(
    //     @ptrCast(self.depthStencilBuffer),
    //     @ptrCast(&depthStencilViewDesc),
    //     @ptrCast(&self.depthStencilView),
    // ));

    // self.device.OMSetRenderTargets(1, @ptrCast(&self.targetView), self.depthStencilView);
}

pub fn beginScene(self: *@This(), red: f32, green: f32, blue: f32, alpha: f32) void {
    const color = [_]f32{ red, green, blue, alpha };
    self.device.ClearRenderTargetView(self.targetView, @ptrCast(&color));

    // const clearDepth: i32 = @intCast(@intFromEnum(d10.D3D10_CLEAR_DEPTH));
    // self.device.ClearDepthStencilView(self.depthStencilView, clearDepth, 1, 0);
    win32Check(self.swapChain.Present(0, 0));
}

pub fn endScene(self: *@This()) void {
    _ = self;
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
