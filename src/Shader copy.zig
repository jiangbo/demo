const std = @import("std");
const win32 = @import("win32");

const d10 = win32.graphics.direct3d10;

layout: *d10.ID3D10InputLayout,
vertexShader: *d10.ID3D10VertexShader,

pub fn initialize(device: *d10.ID3D10Device) @This() {
    const vertex = compileShader(win32.zig.L("vs.hlsl"), "vs_4_0");
    defer _ = vertex.IUnknown.Release();

    var vs: ?*d10.ID3D10VertexShader = null;
    const byteCode: [*]u8 = @ptrCast(vertex.GetBufferPointer());
    const size = vertex.GetBufferSize();
    win32Check(device.CreateVertexShader(byteCode, size, &vs));

    var desc = std.mem.zeroes(d10.D3D10_INPUT_ELEMENT_DESC);
    desc.SemanticName = "POSITION";
    desc.SemanticIndex = 0;
    desc.Format = .R32G32_FLOAT;
    desc.InputSlotClass = .VERTEX_DATA;
    var layout: ?*d10.ID3D10InputLayout = null;

    const array = [_]d10.D3D10_INPUT_ELEMENT_DESC{desc};
    win32Check(device.CreateInputLayout(&array, array.len, byteCode, size, &layout));

    return .{ .layout = layout.?, .vertexShader = vs.? };
}

pub fn render(self: *@This()) void {
    _ = self;
}

pub fn shutdown(self: *@This()) void {
    _ = self.layout.IUnknown.Release();
    _ = self.vertexShader.IUnknown.Release();
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
