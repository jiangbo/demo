const std = @import("std");
const win32 = @import("win32");
const d3d9 = win32.graphics.direct3d9;

pub const LPCTSTR = [*:0]align(1) const u16;

pub extern fn D3DXCreateTextureFromFileW(
    device: *d3d9.IDirect3DDevice9,
    name: LPCTSTR,
    LPDIRECT3DTEXTURE9: ?**d3d9.IDirect3DTexture9,
) callconv(std.os.windows.WINAPI) win32.foundation.HRESULT;

pub extern fn D3DXMatrixTranslation(
    matrix: *win32.graphics.direct3d.D3DMATRIX,
    x: f32,
    y: f32,
    z: f32,
) *win32.graphics.direct3d.D3DMATRIX;

pub extern fn D3DXMatrixScaling(
    matrix: *win32.graphics.direct3d.D3DMATRIX,
    x: f32,
    y: f32,
    z: f32,
) *win32.graphics.direct3d.D3DMATRIX;

pub extern fn D3DXMatrixRotationX(
    matrix: *win32.graphics.direct3d.D3DMATRIX,
    angle: f32,
) *win32.graphics.direct3d.D3DMATRIX;

pub extern fn D3DXMatrixRotationY(
    matrix: *win32.graphics.direct3d.D3DMATRIX,
    angle: f32,
) *win32.graphics.direct3d.D3DMATRIX;

pub extern fn D3DXMatrixRotationZ(
    matrix: *win32.graphics.direct3d.D3DMATRIX,
    angle: f32,
) *win32.graphics.direct3d.D3DMATRIX;

pub const Vec4 = extern struct { x: f32, y: f32, z: f32, w: f32 };

pub extern fn D3DXVec3Transform(
    vec: *Vec4,
    v: *const win32.graphics.direct3d.D3DVECTOR,
    m: *const win32.graphics.direct3d.D3DMATRIX,
) callconv(std.os.windows.WINAPI) *Vec4;

pub extern fn D3DXMatrixMultiply(
    matrix: *win32.graphics.direct3d.D3DMATRIX,
    m1: *win32.graphics.direct3d.D3DMATRIX,
    m2: *win32.graphics.direct3d.D3DMATRIX,
) *win32.graphics.direct3d.D3DMATRIX;
