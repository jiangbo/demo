const std = @import("std");
const win32 = @import("win32");

const d12 = win32.graphics.direct3d12;
const dxgi = win32.graphics.dxgi;

var d12Debug: *d12.ID3D12Debug5 = undefined;
var dxgiDebug: *dxgi.IDXGIDebug1 = undefined;

pub fn init() void {
    win32Check(d12.D3D12GetDebugInterface(d12.IID_ID3D12Debug5, @ptrCast(&d12Debug)));
    d12Debug.ID3D12Debug.EnableDebugLayer();

    win32Check(dxgi.DXGIGetDebugInterface1(0, dxgi.IID_IDXGIDebug1, @ptrCast(&dxgiDebug)));
    dxgiDebug.EnableLeakTrackingForThread();
}

pub fn deinit() void {
    _ = d12Debug.ID3D12Debug.IUnknown.Release();
    const flags = dxgi.DXGI_DEBUG_RLO_ALL;
    win32Check(dxgiDebug.IDXGIDebug.ReportLiveObjects(dxgi.DXGI_DEBUG_ALL, flags));
    _ = dxgiDebug.IUnknown.Release();
}

pub fn win32Check(result: win32.foundation.HRESULT) void {
    if (win32.zig.SUCCEEDED(result)) return;
    @panic(@tagName(win32.foundation.GetLastError()));
}
