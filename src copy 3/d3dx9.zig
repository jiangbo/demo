const std = @import("std");
const win32 = @import("win32");

const d3d9 = win32.graphics.direct3d9;
pub const LPCTSTR = [*:0]const u16;

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
