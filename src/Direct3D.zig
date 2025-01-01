const std = @import("std");
const win32 = @import("win32");

const dxgi = win32.graphics.dxgi;

width: u16,
height: u16,
vsync: bool,
depth: f32,
near: f32,

pub fn initialize(self: *@This(), window: ?win32.foundation.HWND) void {
    _ = window;
    self.width = 0;
    var factory: *dxgi.IDXGIFactory = undefined;
    win32Check(dxgi.CreateDXGIFactory(dxgi.IID_IDXGIFactory, @ptrCast(&factory)));

    var adapter: *dxgi.IDXGIAdapter = undefined;
    win32Check(factory.EnumAdapters(0, @ptrCast(&adapter)));

    var output: *dxgi.IDXGIOutput = undefined;
    win32Check(adapter.EnumOutputs(0, @ptrCast(&output)));

    var modeCount: u32 = 0;
    const mode = dxgi.DXGI_ENUM_MODES_INTERLACED;
    var displayModeList: [200]dxgi.common.DXGI_MODE_DESC = undefined;
    win32Check(output.GetDisplayModeList(.R8G8B8A8_UNORM, mode, &modeCount, null));
    std.log.info("mode count: {}", .{modeCount});

    win32Check(output.GetDisplayModeList(.R8G8B8A8_UNORM, mode, &modeCount, &displayModeList));

    const modes = displayModeList[0..modeCount];

    for (modes) |value| {
        std.log.info("{}", .{value});
    }
}

pub fn beginScene(self: *@This(), red: f32, green: f32, blue: f32, alpha: f32) void {
    _ = self;
    _ = red;
    _ = green;
    _ = blue;
    _ = alpha;
}

pub fn endScene(self: *@This()) void {
    _ = self;
}

pub fn shutdown(self: *@This()) void {
    _ = self;
}

fn win32Check(result: win32.foundation.HRESULT) void {
    if (win32.zig.SUCCEEDED(result)) return;
    @panic(@tagName(win32.foundation.GetLastError()));
}
