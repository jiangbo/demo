const std = @import("std");
const win32 = @import("win32");

const d11 = win32.graphics.direct3d11;

vertexShader: *d11.ID3D11VertexShader = undefined,
vertexLayout: *d11.ID3D11InputLayout = undefined,
pixelShader: *d11.ID3D11PixelShader = undefined,

pub fn initialize(device: *d11.ID3D11Device) @This() {
    var self: @This() = .{};

    const vertex = compileShader(win32.zig.L("vs.hlsl"), "vs_5_0");
    defer _ = vertex.IUnknown.Release();

    var byteCode: [*]u8 = @ptrCast(vertex.GetBufferPointer());
    var size = vertex.GetBufferSize();
    win32Check(device.CreateVertexShader(byteCode, size, null, &self.vertexShader));

    var position = std.mem.zeroes(d11.D3D11_INPUT_ELEMENT_DESC);
    position.SemanticName = "POSITION";
    position.SemanticIndex = 0;
    position.Format = .R32G32B32_FLOAT;
    position.InputSlotClass = .VERTEX_DATA;

    var color = std.mem.zeroes(d11.D3D11_INPUT_ELEMENT_DESC);
    color.SemanticName = "COLOR";
    color.SemanticIndex = 0;
    color.Format = .R32G32B32_FLOAT;
    color.AlignedByteOffset = d11.D3D11_APPEND_ALIGNED_ELEMENT;
    color.InputSlotClass = .VERTEX_DATA;

    const array = [_]d11.D3D11_INPUT_ELEMENT_DESC{ position, color };
    win32Check(device.CreateInputLayout(&array, array.len, byteCode, size, &self.vertexLayout));

    const pixel = compileShader(win32.zig.L("ps.hlsl"), "ps_5_0");
    defer _ = pixel.IUnknown.Release();

    byteCode = @ptrCast(pixel.GetBufferPointer());
    size = pixel.GetBufferSize();
    win32Check(device.CreatePixelShader(byteCode, size, null, &self.pixelShader));

    return self;
}

pub fn render(self: *@This(), deviceContext: *d11.ID3D11DeviceContext) void {
    deviceContext.IASetInputLayout(self.vertexLayout);
    deviceContext.IASetPrimitiveTopology(._PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    deviceContext.VSSetShader(self.vertexShader, null, 0);
    deviceContext.PSSetShader(self.pixelShader, null, 0);
}

pub fn shutdown(self: *@This()) void {
    _ = self.vertexShader.IUnknown.Release();
    _ = self.vertexLayout.IUnknown.Release();
    _ = self.pixelShader.IUnknown.Release();
}

const ID3DBlob = win32.graphics.direct3d.ID3DBlob;
const fxc = win32.graphics.direct3d.fxc;
pub fn compileShader(srcName: [*:0]const u16, target: [*:0]const u8) *ID3DBlob {
    var r: ?*ID3DBlob = null;
    var blob: ?*ID3DBlob = null;

    const flags = fxc.D3DCOMPILE_ENABLE_STRICTNESS //
    | fxc.D3DCOMPILE_DEBUG | fxc.D3DCOMPILE_SKIP_OPTIMIZATION;
    _ = fxc.D3DCompileFromFile(srcName, null, null, "main", target, flags, 0, &r, &blob);
    shaderCheck(blob);
    return r.?;
}

fn shaderCheck(errorBlob: ?*ID3DBlob) void {
    if (errorBlob) |blob| {
        const msg: [*]u8 = @ptrCast(blob.GetBufferPointer());
        @panic(msg[0..blob.GetBufferSize()]);
    }
}

fn win32Check(result: win32.foundation.HRESULT) void {
    if (win32.zig.SUCCEEDED(result)) return;
    @panic(@tagName(win32.foundation.GetLastError()));
}
