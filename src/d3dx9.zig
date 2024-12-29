const std = @import("std");
const win32 = @import("win32");

const d3d9 = win32.graphics.direct3d9;
pub const LPCTSTR = [*:0]const u16;
const HRESULT = win32.foundation.HRESULT;

pub extern fn D3DXLoadSurfaceFromFileW(
    surface: *d3d9.IDirect3DSurface9,
    palette: ?*const win32.graphics.gdi.PALETTEENTRY,
    rect: ?*const win32.foundation.RECT,
    srcFile: LPCTSTR,
    srcRect: ?*const win32.foundation.RECT,
    filter: u32,
    colorkey: u32,
    srcInfo: usize,
) callconv(std.os.windows.WINAPI) win32.foundation.HRESULT;

pub extern fn D3DXCreateTextureFromFileW(
    device: *d3d9.IDirect3DDevice9,
    name: LPCTSTR,
    LPDIRECT3DTEXTURE9: ?**d3d9.IDirect3DTexture9,
) callconv(std.os.windows.WINAPI) win32.foundation.HRESULT;

pub extern fn D3DXCreateTextureFromFileExW(
    device: *d3d9.IDirect3DDevice9,
    name: LPCTSTR,
    width: u32,
    height: u32,
    mipLevels: u32,
    usage: u32,
    format: d3d9.D3DFORMAT,
    pool: d3d9.D3DPOOL,
    filter: u32,
    mipFilter: u32,
    colorkey: u32,
    pSrcInfo: usize,
    pPalette: ?*const win32.graphics.gdi.PALETTEENTRY,
    ppTexture: ?**d3d9.IDirect3DTexture9,
) callconv(std.os.windows.WINAPI) win32.foundation.HRESULT;

pub const D3DX_DEFAULT = 0xffffffff;
pub const D3DXSPRITE_ALPHABLEND: u32 = 1 << 4;

pub extern fn D3DXCreateSprite(
    device: *d3d9.IDirect3DDevice9,
    sprite: ?**ID3DXSprite,
) callconv(std.os.windows.WINAPI) win32.foundation.HRESULT;

pub const ID3DXSprite = extern union {
    pub const VTable = extern struct {
        base: win32.system.com.IUnknown.VTable,

        GetDevice: usize,

        GetTransform: usize,
        SetTransform: usize,
        SetWorldViewRH: usize,
        SetWorldViewLH: usize,

        Begin: *const fn (self: *ID3DXSprite, flags: u32) //
        callconv(std.os.windows.WINAPI) win32.foundation.HRESULT,
        Draw: *const fn (
            self: *ID3DXSprite,
            texture: *d3d9.IDirect3DTexture9,
            srcRect: ?*const win32.foundation.RECT,
            center: ?*const win32.graphics.direct3d.D3DVECTOR,
            position: ?*const win32.graphics.direct3d.D3DVECTOR,
            color: u32,
        ) callconv(std.os.windows.WINAPI) win32.foundation.HRESULT,
        Flush: usize,
        End: *const fn (
            self: *ID3DXSprite,
        ) callconv(std.os.windows.WINAPI) win32.foundation.HRESULT,

        OnLostDevice: usize,
        OnResetDevice: usize,
    };

    vtable: *const VTable,
    IUnknown: win32.system.com.IUnknown,

    pub fn Begin(self: *ID3DXSprite, flags: u32) callconv(.Inline) HRESULT {
        return self.vtable.Begin(self, flags);
    }

    pub fn Draw(
        self: *ID3DXSprite,
        texture: *d3d9.IDirect3DTexture9,
        srcRect: ?*const win32.foundation.RECT,
        center: ?*const win32.graphics.direct3d.D3DVECTOR,
        position: ?*const win32.graphics.direct3d.D3DVECTOR,
        color: u32,
    ) callconv(.Inline) HRESULT {
        return self.vtable.Draw(self, texture, srcRect, center, position, color);
    }

    pub fn End(self: *ID3DXSprite) callconv(.Inline) HRESULT {
        return self.vtable.End(self);
    }
};
