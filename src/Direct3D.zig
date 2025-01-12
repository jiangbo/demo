const std = @import("std");
const win32 = @import("win32");

const dxgi = win32.graphics.dxgi;
const d12 = win32.graphics.direct3d12;

var d12Debug: *d12.ID3D12Debug5 = undefined;
var dxgiDebug: *dxgi.IDXGIDebug1 = undefined;

factory: *dxgi.IDXGIFactory7 = undefined,
device: *d12.ID3D12Device9 = undefined,

commandQueue: *d12.ID3D12CommandQueue = undefined,
commandAllocator: *d12.ID3D12CommandAllocator = undefined,

swapChain: *dxgi.IDXGISwapChain4 = undefined,
descriptorHeap: *d12.ID3D12DescriptorHeap = undefined,
targetView: *d12.ID3D12Resource = undefined,
backBuffers: [2]*d12.ID3D12Resource = undefined,

pub fn initialize(self: *@This(), w: u16, h: u16, window: ?win32.foundation.HWND) void {
    initDebug();

    self.initDevice();
    self.initCommand();
    self.initSwapChain(w, h, window);
    self.initDescriptor();
    self.initTargetView();
}

fn initDebug() void {
    win32Check(d12.D3D12GetDebugInterface(d12.IID_ID3D12Debug5, @ptrCast(&d12Debug)));
    d12Debug.ID3D12Debug.EnableDebugLayer();
    d12Debug.ID3D12Debug3.SetEnableGPUBasedValidation(win32.zig.TRUE);

    win32Check(dxgi.DXGIGetDebugInterface1(0, dxgi.IID_IDXGIDebug1, @ptrCast(&dxgiDebug)));
    dxgiDebug.EnableLeakTrackingForThread();
}

fn initDevice(self: *@This()) void {
    const flags = dxgi.DXGI_CREATE_FACTORY_DEBUG;
    var id = dxgi.IID_IDXGIFactory7;
    win32Check(dxgi.CreateDXGIFactory2(flags, id, @ptrCast(&self.factory)));

    id = d12.IID_ID3D12Device9;
    win32Check(d12.D3D12CreateDevice(null, .@"12_1", id, @ptrCast(&self.device)));
}

fn initCommand(self: *@This()) void {
    var queueDesc = std.mem.zeroes(d12.D3D12_COMMAND_QUEUE_DESC);
    queueDesc.Flags = d12.D3D12_COMMAND_QUEUE_FLAG_NONE;
    queueDesc.Type = .DIRECT;

    win32Check(self.device.ID3D12Device.CreateCommandQueue(
        &queueDesc,
        d12.IID_ID3D12CommandQueue,
        @ptrCast(&self.commandQueue),
    ));

    win32Check(self.device.ID3D12Device.CreateCommandAllocator(
        .DIRECT,
        d12.IID_ID3D12CommandAllocator,
        @ptrCast(&self.commandAllocator),
    ));
}

fn initSwapChain(self: *@This(), w: u16, h: u16, window: ?win32.foundation.HWND) void {
    var desc = std.mem.zeroes(dxgi.DXGI_SWAP_CHAIN_DESC1);
    desc.Width = w;
    desc.Height = h;
    desc.Format = .R8G8B8A8_UNORM;
    desc.SampleDesc = .{ .Count = 1, .Quality = 0 };
    desc.BufferUsage = dxgi.DXGI_USAGE_RENDER_TARGET_OUTPUT;
    desc.BufferCount = self.backBuffers.len;
    desc.SwapEffect = .FLIP_DISCARD;

    win32Check(self.factory.IDXGIFactory2.CreateSwapChainForHwnd(@ptrCast(self.commandQueue), //
        window, &desc, null, null, @ptrCast(&self.swapChain)));

    win32Check(self.factory.IDXGIFactory.MakeWindowAssociation(window, dxgi.DXGI_MWA_NO_ALT_ENTER));
}

fn initDescriptor(self: *@This()) void {
    var desc = std.mem.zeroes(d12.D3D12_DESCRIPTOR_HEAP_DESC);
    desc.NumDescriptors = self.backBuffers.len;
    desc.Type = .RTV;
    win32Check(self.device.ID3D12Device.CreateDescriptorHeap(&desc, //
        d12.IID_ID3D12DescriptorHeap, @ptrCast(&self.descriptorHeap)));
}

fn initTargetView(self: *@This()) void {
    const offset = self.device.ID3D12Device.GetDescriptorHandleIncrementSize(.RTV);

    var handle = self.descriptorHeap.GetCPUDescriptorHandleForHeapStart();
    for (0..self.backBuffers.len) |i| {
        const index: u32 = @intCast(i);

        win32Check(self.swapChain.IDXGISwapChain.GetBuffer(index, d12.IID_ID3D12Resource, //
            @ptrCast(&self.backBuffers[i])));

        self.device.ID3D12Device.CreateRenderTargetView(self.backBuffers[i], null, handle);
        handle.ptr += offset;
    }
}

pub fn beginScene(self: *@This(), red: f32, green: f32, blue: f32, alpha: f32) void {
    // const color = [_]f32{ red, green, blue, alpha };
    // self.deviceContext.ClearRenderTargetView(self.targetView, @ptrCast(&color));
    _ = self;
    _ = red;
    _ = green;
    _ = blue;
    _ = alpha;
}

pub fn render(self: *@This()) void {
    _ = self;
}

pub fn endScene(self: *@This()) void {
    // win32Check(self.swapChain.IDXGISwapChain.Present(1, 0));
    _ = self;
}

pub fn shutdown(self: *@This()) void {
    _ = self.factory.IUnknown.Release();
    _ = self.device.IUnknown.Release();

    _ = self.commandQueue.IUnknown.Release();
    _ = self.commandAllocator.IUnknown.Release();
    _ = self.swapChain.IUnknown.Release();
    _ = self.descriptorHeap.IUnknown.Release();
    for (self.backBuffers) |back| {
        _ = back.IUnknown.Release();
    }

    _ = d12Debug.ID3D12Debug.IUnknown.Release();
    const flags = dxgi.DXGI_DEBUG_RLO_ALL;
    win32Check(dxgiDebug.IDXGIDebug.ReportLiveObjects(dxgi.DXGI_DEBUG_ALL, flags));
    _ = dxgiDebug.IUnknown.Release();
}

fn win32Check(result: win32.foundation.HRESULT) void {
    if (win32.zig.SUCCEEDED(result)) return;
    @panic(@tagName(win32.foundation.GetLastError()));
}
