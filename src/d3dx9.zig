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
