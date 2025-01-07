const std = @import("std");
const win32 = @import("win32");

const d11 = win32.graphics.direct3d11;

vertexBuffer: *d11.ID3D11Buffer = undefined,

pub fn initialize(device: *d11.ID3D11Device) @This() {
    const vertices = [_]f32{
        -0.4, -0.4, 0.4, 0, 1, 0,
        0,    0.4,  0.4, 0, 1, 0,
        0.4,  -0.4, 0.4, 0, 1, 0,
        // -0.4, -0.4, 0.9, 0, 1, 0,
        // 0,    0.4,  0.9, 0, 1, 0,
        // 0.4,  -0.4, 0.9, 0, 1, 0,
        -0.8, -0.8, 0.8, 1, 0, 0,
        0,    0.8,  0.8, 1, 0, 0,
        0.8,  -0.8, 0.8, 1, 0, 0,
    };

    var bufferDesc = std.mem.zeroes(d11.D3D11_BUFFER_DESC);
    bufferDesc.ByteWidth = @sizeOf(@TypeOf(vertices));
    bufferDesc.BindFlags = d11.D3D11_BIND_VERTEX_BUFFER;

    var initData = std.mem.zeroes(d11.D3D11_SUBRESOURCE_DATA);
    initData.pSysMem = &vertices;

    var vertexBuffer: *d11.ID3D11Buffer = undefined;
    win32Check(device.CreateBuffer(&bufferDesc, &initData, @ptrCast(&vertexBuffer)));

    return .{ .vertexBuffer = vertexBuffer };
}

pub fn render(self: *@This(), deviceContext: *d11.ID3D11DeviceContext) void {
    const strides = [_]u32{@sizeOf(f32) * 6};
    var buffers = [_]?*d11.ID3D11Buffer{self.vertexBuffer};
    deviceContext.IASetVertexBuffers(0, 1, &buffers, &strides, &.{0});
}

pub fn shutdown(self: *@This()) void {
    _ = self.vertexBuffer.IUnknown.Release();
}

fn win32Check(result: win32.foundation.HRESULT) void {
    if (win32.zig.SUCCEEDED(result)) return;
    @panic(@tagName(win32.foundation.GetLastError()));
}
