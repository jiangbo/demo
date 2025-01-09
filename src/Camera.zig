const std = @import("std");
const win32 = @import("win32");
const zm = @import("zm");

const d11 = win32.graphics.direct3d11;

model: zm.Mat,
view: zm.Mat,
projection: zm.Mat,
matrixBuffer: *d11.ID3D11Buffer = undefined,

pub fn init(device: *d11.ID3D11Device, width: u16, height: u16) @This() {
    var self: @This() = undefined;
    // 模型矩阵
    self.model = zm.identity();

    // 视图矩阵
    const eve = zm.f32x4(0, 0, -2, 0);
    const look = zm.f32x4(0, 0, 0, 0);
    const up = zm.f32x4(0, 1, 0, 0);
    self.view = zm.lookAtLh(eve, look, up);

    // 投影矩阵
    const fov = std.math.pi / 2.0;
    const aspect = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height));
    const near = 0.1;
    const far = 1000.0;
    self.projection = zm.perspectiveFovLh(fov, aspect, near, far);

    var bufferDesc = std.mem.zeroes(d11.D3D11_BUFFER_DESC);
    bufferDesc.ByteWidth = @sizeOf(zm.Mat);
    bufferDesc.BindFlags = d11.D3D11_BIND_CONSTANT_BUFFER;

    win32Check(device.CreateBuffer(&bufferDesc, null, &self.matrixBuffer));

    return self;
}

pub fn render(self: *@This(), deviceContext: *d11.ID3D11DeviceContext) void {
    const mvp = zm.mul(zm.mul(self.model, self.view), self.projection);

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
