const std = @import("std");
const win32 = @import("win32");
const Bitmap = @import("Bitmap.zig");
const zm = @import("zm");

const d11 = win32.graphics.direct3d11;

model: zm.Mat,
textureView: *d11.ID3D11ShaderResourceView,

pub fn init(device: *d11.ID3D11Device, name: [:0]const u8) @This() {
    var bitmap = Bitmap.init(name) catch unreachable;
    defer bitmap.deinit();

    var textureDesc = std.mem.zeroes(d11.D3D11_TEXTURE2D_DESC);
    textureDesc.Width = @intCast(bitmap.infoHeader.biWidth);
    textureDesc.Height = @intCast(bitmap.infoHeader.biHeight);
    textureDesc.MipLevels = 1;
    textureDesc.ArraySize = 1;
    textureDesc.Format = .B8G8R8X8_UNORM;
    textureDesc.SampleDesc.Count = 1;
    textureDesc.Usage = .DEFAULT;
    textureDesc.BindFlags = d11.D3D11_BIND_SHADER_RESOURCE;

    var initialData = std.mem.zeroes(d11.D3D11_SUBRESOURCE_DATA);
    initialData.pSysMem = @ptrCast(bitmap.buffer.ptr);
    initialData.SysMemPitch = textureDesc.Width * 4;

    var texture: *d11.ID3D11Texture2D = undefined;
    win32Check(device.CreateTexture2D(&textureDesc, &initialData, &texture));

    var srvDesc = std.mem.zeroes(d11.D3D11_SHADER_RESOURCE_VIEW_DESC);
    srvDesc.Format = textureDesc.Format;
    srvDesc.ViewDimension = ._SRV_DIMENSION_TEXTURE2D;
    srvDesc.Anonymous.Texture2D.MipLevels = 1;

    var textureView: *d11.ID3D11ShaderResourceView = undefined;
    win32Check(device.CreateShaderResourceView(@ptrCast(texture), &srvDesc, &textureView));
    const width: f32 = @floatFromInt(textureDesc.Width);
    const height: f32 = @floatFromInt(textureDesc.Height);

    return .{ .model = zm.scaling(width, height, 1), .textureView = textureView };
}

pub fn draw(self: *@This(), context: *d11.ID3D11DeviceContext) void {
    context.PSSetShaderResources(0, 1, @ptrCast(&self.textureView));
}

pub fn deinit(self: *@This()) void {
    _ = self.textureView.IUnknown.Release();
}

fn win32Check(result: win32.foundation.HRESULT) void {
    if (win32.zig.SUCCEEDED(result)) return;
    @panic(@tagName(win32.foundation.GetLastError()));
}
