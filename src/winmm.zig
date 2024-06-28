const std = @import("std");
const win32 = @import("win32");

const H = std.os.windows.HINSTANCE;
const WINAPI = std.os.windows.WINAPI;
pub const LPCTSTR = [*:0]align(1) const u16;
const BOOL = win32.foundation.BOOL;

pub const SND_RESOURCE: u32 = 0x00040004;
pub const SND_SYNC: u32 = 0x0000;
pub const SND_ASYNC: u32 = 0x0001;
pub const SND_LOOP: u32 = 0x0008;
pub const SND_PURGE: u32 = 0x0040;

pub extern fn PlaySoundW(n: ?LPCTSTR, w: H, f: u32) callconv(WINAPI) BOOL;
