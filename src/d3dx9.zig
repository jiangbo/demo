const std = @import("std");
const win32 = @import("win32");
const d3d9 = win32.graphics.direct3d9;

pub const LPCTSTR = [*:0]align(1) const u16;

pub extern fn D3DXMatrixPerspectiveFovLH(
    matrix: *win32.graphics.direct3d.D3DMATRIX,
    fovy: f32,
    aspect: f32,
    zn: f32,
    zf: f32,
) *win32.graphics.direct3d.D3DMATRIX;

pub extern fn D3DXMatrixLookAtLH(
    matrix: *win32.graphics.direct3d.D3DMATRIX,
    eye: *const Vec3,
    at: *const Vec3,
    up: *const Vec3,
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

pub extern fn D3DXMatrixMultiply(
    matrix: *win32.graphics.direct3d.D3DMATRIX,
    m1: *const win32.graphics.direct3d.D3DMATRIX,
    m2: *const win32.graphics.direct3d.D3DMATRIX,
) *win32.graphics.direct3d.D3DMATRIX;

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

pub extern fn D3DXMatrixReflect(
    matrix: *win32.graphics.direct3d.D3DMATRIX,
    plane: *const Vec4,
) *win32.graphics.direct3d.D3DMATRIX;

pub extern fn D3DXMatrixShadow(
    matrix: *win32.graphics.direct3d.D3DMATRIX,
    light: *const Vec4,
    plane: *const Vec4,
) *win32.graphics.direct3d.D3DMATRIX;

pub extern fn D3DXCreateTextureFromFileW(
    device: *d3d9.IDirect3DDevice9,
    name: LPCTSTR,
    LPDIRECT3DTEXTURE9: ?**d3d9.IDirect3DTexture9,
) callconv(std.os.windows.WINAPI) win32.foundation.HRESULT;

pub extern fn D3DXCreateTeapot(
    device: *d3d9.IDirect3DDevice9,
    mesh: **ID3DXMesh,
    buffer: ?**ID3DXBuffer,
) callconv(std.os.windows.WINAPI) win32.foundation.HRESULT;

pub const Vec4 = extern struct { x: f32, y: f32, z: f32, w: f32 };
pub const Vec3 = extern struct { x: f32 = 0, y: f32 = 0, z: f32 = 0 };

pub const ID3DXMesh = extern struct {
    pub const VTable = extern struct {
        base: ID3DXBaseMesh.VTable,
    };
    vtable: *const VTable,
    pub fn MethodMixin(comptime T: type) type {
        return struct {
            pub inline fn ID3DXBaseMesh_DrawSubset(self: *const T, attribId: u32) i32 {
                return @as(*const ID3DXBaseMesh.VTable, @ptrCast(self.vtable)).DrawSubset(@as(*const ID3DXBaseMesh, @ptrCast(self)), attribId);
            }
        };
    }
    pub usingnamespace MethodMixin(@This());
};

pub const ID3DXBaseMesh = extern struct {
    pub const VTable = extern struct {
        base: win32.system.com.IUnknown.VTable,
        DrawSubset: *const fn (
            self: *const ID3DXBaseMesh,
            attribId: u32,
        ) callconv(std.os.windows.WINAPI) win32.foundation.HRESULT,
    };
    vtable: *const VTable,
};

pub const ID3DXBuffer = extern struct {
    pub const VTable = extern struct {
        base: win32.system.com.IUnknown.VTable,
    };
    vtable: *const VTable,
};
