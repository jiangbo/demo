const std = @import("std");
const win32 = @import("win32");
const zm = @import("zm");

const d11 = win32.graphics.direct3d11;

view: zm.Mat,
projection: zm.Mat,
matrixBuffer: *d11.ID3D11Buffer = undefined,

pub fn init(device: *d11.ID3D11Device, width: u16, height: u16) @This() {
    var self: @This() = undefined;

    // 视图矩阵
    self.view = zm.identity();
    self.projection = zm.orthographicLh(@floatFromInt(width), @floatFromInt(height), 0, 1);

    var bufferDesc = std.mem.zeroes(d11.D3D11_BUFFER_DESC);
    bufferDesc.ByteWidth = @sizeOf(zm.Mat);
    bufferDesc.BindFlags = d11.D3D11_BIND_CONSTANT_BUFFER;

    win32Check(device.CreateBuffer(&bufferDesc, null, &self.matrixBuffer));

    return self;
}

pub fn render(self: *@This(), deviceContext: *d11.ID3D11DeviceContext, model: zm.Mat) void {
    const mvp = zm.mul(zm.mul(model, self.view), self.projection);

    deviceContext.UpdateSubresource(@ptrCast(self.matrixBuffer), 0, null, &mvp, 0, 0);
    deviceContext.VSSetConstantBuffers(0, 1, @ptrCast(&self.matrixBuffer));
}

pub fn deinit(self: *@This()) void {
    _ = self.matrixBuffer.IUnknown.Release();
}

fn win32Check(result: win32.foundation.HRESULT) void {
    if (win32.zig.SUCCEEDED(result)) return;
    @panic(@tagName(win32.foundation.GetLastError()));
}
