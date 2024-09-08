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

pub extern fn D3DXCreateTextW(
    device: *d3d9.IDirect3DDevice9,
    hdc: win32.graphics.gdi.HDC,
    str: [*]align(1) const u16,
    deviation: f32,
    extrusion: f32,
    mesh: **ID3DXMesh,
    adjacency: ?**ID3DXBuffer,
    glyphMetrics: ?*win32.everything.GLYPHMETRICSFLOAT,
) callconv(std.os.windows.WINAPI) win32.foundation.HRESULT;

pub extern fn D3DXComputeBoundingSphere(
    firstPosition: *const Vec3,
    numVertices: u32,
    stride: u32,
    center: *Vec3,
    radius: *f32,
) callconv(std.os.windows.WINAPI) win32.foundation.HRESULT;

pub extern fn D3DXGetFVFVertexSize(fvf: u32) callconv(std.os.windows.WINAPI) u32;

pub extern fn D3DXCreateSphere(
    device: *d3d9.IDirect3DDevice9,
    radius: f32,
    slices: u32,
    stacks: u32,
    mesh: **ID3DXMesh,
    adjacency: ?**ID3DXBuffer,
) callconv(std.os.windows.WINAPI) win32.foundation.HRESULT;

pub extern fn D3DXMatrixInverse(
    out: *win32.graphics.direct3d.D3DMATRIX,
    determinant: ?*f32,
    matrix: *const win32.graphics.direct3d.D3DMATRIX,
) *win32.graphics.direct3d.D3DMATRIX;

pub extern fn D3DXVec3TransformCoord(
    out: *Vec3,
    v: *const Vec3,
    matrix: *const win32.graphics.direct3d.D3DMATRIX,
) *Vec3;

pub extern fn D3DXVec3TransformNormal(
    out: *Vec3,
    v: *const Vec3,
    matrix: *const win32.graphics.direct3d.D3DMATRIX,
) *Vec3;

pub const Vec4 = extern struct { x: f32, y: f32, z: f32, w: f32 };
pub const Vec3 = extern struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return Vec3{
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
        };
    }

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return Vec3{
            .x = self.x - other.x,
            .y = self.y - other.y,
            .z = self.z - other.z,
        };
    }

    pub fn dot(self: Vec3, other: Vec3) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn normalize(self: Vec3) Vec3 {
        const len = @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
        return Vec3{
            .x = self.x / len,
            .y = self.y / len,
            .z = self.z / len,
        };
    }
};

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
            pub inline fn ID3DXBaseMesh_LockVertexBuffer(
                self: *const T,
                flags: u32,
                data: *anyopaque,
            ) i32 {
                return @as(*const ID3DXBaseMesh.VTable, @ptrCast(self.vtable)).LockVertexBuffer(@as(*const ID3DXBaseMesh, @ptrCast(self)), flags, data);
            }
            pub inline fn ID3DXBaseMesh_GetNumVertices(self: *const T) u32 {
                return @as(*const ID3DXBaseMesh.VTable, @ptrCast(self.vtable)).GetNumVertices(@as(*const ID3DXBaseMesh, @ptrCast(self)));
            }
            pub inline fn ID3DXBaseMesh_GetFVF(self: *const T) u32 {
                return @as(*const ID3DXBaseMesh.VTable, @ptrCast(self.vtable)).GetFVF(@as(*const ID3DXBaseMesh, @ptrCast(self)));
            }
            pub inline fn ID3DXBaseMesh_UnlockVertexBuffer(self: *const T) i32 {
                return @as(*const ID3DXBaseMesh.VTable, @ptrCast(self.vtable)).UnlockVertexBuffer(@as(*const ID3DXBaseMesh, @ptrCast(self)));
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
        GetNumFaces: usize,
        GetNumVertices: *const fn (
            self: *const ID3DXBaseMesh,
        ) callconv(std.os.windows.WINAPI) u32,
        GetFVF: *const fn (
            self: *const ID3DXBaseMesh,
        ) callconv(std.os.windows.WINAPI) u32,
        _: [8]usize,
        LockVertexBuffer: *const fn (
            self: *const ID3DXBaseMesh,
            flags: u32,
            data: *anyopaque,
        ) callconv(std.os.windows.WINAPI) win32.foundation.HRESULT,
        UnlockVertexBuffer: *const fn (
            self: *const ID3DXBaseMesh,
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
