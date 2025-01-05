const std = @import("std");
const win32 = @import("win32");

const d10 = win32.graphics.direct3d10;

vertexBuffer: *d10.ID3D10Buffer = undefined,

pub fn initialize(device: *d10.ID3D10Device) @This() {
    const vertices = [_]f32{ -0.5, -0.5, 0.0, 0.5, 0.5, -0.5 };

    var bufferDesc = std.mem.zeroes(d10.D3D10_BUFFER_DESC);
    bufferDesc.ByteWidth = @sizeOf(@TypeOf(vertices));
    bufferDesc.BindFlags = @intFromEnum(d10.D3D10_BIND_VERTEX_BUFFER);

    var initData = std.mem.zeroes(d10.D3D10_SUBRESOURCE_DATA);
    initData.pSysMem = &vertices;

    var vertexBuffer: *d10.ID3D10Buffer = undefined;
    win32Check(device.CreateBuffer(&bufferDesc, &initData, @ptrCast(&vertexBuffer)));

    return .{ .vertexBuffer = vertexBuffer };
}

pub fn render(self: *@This(), device: *d10.ID3D10Device) void {
    const strides = [_]u32{@sizeOf(f32) * 2};
    var buffers = [_]?*d10.ID3D10Buffer{self.vertexBuffer};
    device.IASetVertexBuffers(0, 1, &buffers, &strides, &.{0});
}

pub fn shutdown(self: *@This()) void {
    _ = self.vertexBuffer.IUnknown.Release();
}

fn win32Check(result: win32.foundation.HRESULT) void {
    if (win32.zig.SUCCEEDED(result)) return;
    @panic(@tagName(win32.foundation.GetLastError()));
}
