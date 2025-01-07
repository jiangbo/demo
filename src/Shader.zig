const std = @import("std");
const win32 = @import("win32");

const d11 = win32.graphics.direct3d11;

vertexShader: *d11.ID3D11VertexShader = undefined,
vertexLayout: *d11.ID3D11InputLayout = undefined,
pixelShader: *d11.ID3D11PixelShader = undefined,
samplerState: *d11.ID3D11SamplerState = undefined,

pub fn initialize(device: *d11.ID3D11Device) @This() {
    var self: @This() = .{};

    self.initVertexShaderAndLayout(device);
    self.initPixelShader(device);
    self.initSamplerState(device);

    return self;
}

fn initVertexShaderAndLayout(self: *@This(), device: *d11.ID3D11Device) void {
    const vertex = compileShader(win32.zig.L("vs.hlsl"), "vs_5_0");
    defer _ = vertex.IUnknown.Release();

    const byteCode: [*]u8 = @ptrCast(vertex.GetBufferPointer());
    const size = vertex.GetBufferSize();
    win32Check(device.CreateVertexShader(byteCode, size, null, &self.vertexShader));

    var position = std.mem.zeroes(d11.D3D11_INPUT_ELEMENT_DESC);
    position.SemanticName = "POSITION";
    position.SemanticIndex = 0;
    position.Format = .R32G32B32_FLOAT;
    position.InputSlotClass = .VERTEX_DATA;

    var color = std.mem.zeroes(d11.D3D11_INPUT_ELEMENT_DESC);
    color.SemanticName = "TEXCOORD";
    color.SemanticIndex = 0;
    color.Format = .R32G32_FLOAT;
    color.AlignedByteOffset = d11.D3D11_APPEND_ALIGNED_ELEMENT;
    color.InputSlotClass = .VERTEX_DATA;

    const array = [_]d11.D3D11_INPUT_ELEMENT_DESC{ position, color };
    win32Check(device.CreateInputLayout(&array, array.len, byteCode, size, &self.vertexLayout));
}

fn initPixelShader(self: *@This(), device: *d11.ID3D11Device) void {
    const pixel = compileShader(win32.zig.L("ps.hlsl"), "ps_5_0");

    defer _ = pixel.IUnknown.Release();

    const byteCode: [*]u8 = @ptrCast(pixel.GetBufferPointer());
    const size = pixel.GetBufferSize();
    win32Check(device.CreatePixelShader(byteCode, size, null, &self.pixelShader));
}

fn initSamplerState(self: *@This(), device: *d11.ID3D11Device) void {
    var samplerDesc = std.mem.zeroes(d11.D3D11_SAMPLER_DESC);
    samplerDesc.Filter = .MIN_MAG_MIP_LINEAR;
    samplerDesc.AddressU = .WRAP;
    samplerDesc.AddressV = .WRAP;
    samplerDesc.AddressW = .WRAP;
    samplerDesc.ComparisonFunc = .NEVER;
    samplerDesc.MinLOD = 0;
    samplerDesc.MaxLOD = d11.D3D11_FLOAT32_MAX;

    win32Check(device.CreateSamplerState(&samplerDesc, &self.samplerState));
}

pub fn render(self: *@This(), deviceContext: *d11.ID3D11DeviceContext) void {
    deviceContext.IASetInputLayout(self.vertexLayout);
    deviceContext.IASetPrimitiveTopology(._PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    deviceContext.VSSetShader(self.vertexShader, null, 0);
    deviceContext.PSSetShader(self.pixelShader, null, 0);
    deviceContext.PSSetSamplers(0, 1, @ptrCast(&self.samplerState));
}

pub fn shutdown(self: *@This()) void {
    _ = self.vertexShader.IUnknown.Release();
    _ = self.vertexLayout.IUnknown.Release();
    _ = self.pixelShader.IUnknown.Release();
    _ = self.samplerState.IUnknown.Release();
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
