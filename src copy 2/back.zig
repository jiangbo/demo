const std = @import("std");
const win32 = @import("win32");
const zigwin = @import("win.zig");

const draw = win32.graphics.direct_draw;

pub const UNICODE: bool = true;
const WINAPI = std.os.windows.WINAPI;

var draw7: *draw.IDirectDraw7 = undefined;
var surfaceDes: draw.DDSURFACEDESC2 = undefined;
var surface: *draw.IDirectDrawSurface7 = undefined;
var backup: *draw.IDirectDrawSurface7 = undefined;

const H = std.os.windows.HINSTANCE;
pub fn wWinMain(h: H, _: ?H, _: [*:0]u16, _: u32) callconv(WINAPI) i32 {
    zigwin.createWindow(h);

    gameInit();
    zigwin.update(gameUpdate);
    gameShutdown();

    return 0;
}

const failed = win32.zig.FAILED;
fn gameInit() void {
    std.log.info("gameInit", .{});

    if (failed(draw.DirectDrawCreateEx(null, @ptrCast(&draw7), //
        draw.IID_IDirectDraw7, null))) win32Panic();

    const style = draw.DDSCL_FULLSCREEN | draw.DDSCL_ALLOWMODEX |
        draw.DDSCL_EXCLUSIVE | draw.DDSCL_ALLOWREBOOT;

    // const style = draw.DDSCL_NORMAL;
    if (failed(draw7.IDirectDraw7_SetCooperativeLevel(zigwin.hander, style)))
        win32Panic();

    if (failed(draw7.IDirectDraw7_SetDisplayMode(zigwin.WIDTH, //
        zigwin.HEIGHT, 32, 0, 0))) win32Panic();

    surfaceDes = std.mem.zeroes(draw.DDSURFACEDESC2);
    surfaceDes.dwSize = @sizeOf(draw.DDSURFACEDESC2);
    surfaceDes.dwFlags = draw.DDSD_CAPS | draw.DDSD_BACKBUFFERCOUNT;
    surfaceDes.Anonymous2.dwBackBufferCount = 1;
    surfaceDes.ddsCaps.dwCaps = draw.DDSCAPS_PRIMARYSURFACE | //
        draw.DDSCAPS_COMPLEX | draw.DDSCAPS_FLIP;

    if (failed(draw7.IDirectDraw7_CreateSurface(&surfaceDes, //
        @ptrCast(&surface), null))) win32Panic();

    surfaceDes.ddsCaps.dwCaps = draw.DDSCAPS_BACKBUFFER;
    if (failed(surface.IDirectDrawSurface7_GetAttachedSurface( //
        &surfaceDes.ddsCaps, @ptrCast(&backup)))) win32Panic();
}

fn gameUpdate() void {
    // get the time
    // const system = win32.system.system_information;
    // const start = system.GetTickCount64();

    surfaceDes = std.mem.zeroes(draw.DDSURFACEDESC2);
    surfaceDes.dwSize = @sizeOf(draw.DDSURFACEDESC2);

    if (failed(backup.IDirectDrawSurface7_Lock(null, &surfaceDes, //
        draw.DDLOCK_SURFACEMEMORYPTR | draw.DDLOCK_WAIT, null))) win32Panic();

    const backBuffer: [*]u32 = @ptrCast(@alignCast(surfaceDes.lpSurface));
    @memset(backBuffer[0 .. zigwin.WIDTH * zigwin.HEIGHT], 0);

    for (0..10000) |_| {
        const color = zigwin.rand.uintAtMost(u24, std.math.maxInt(u24));
        const x = zigwin.rand.uintLessThan(usize, zigwin.WIDTH);
        const y = zigwin.rand.uintLessThan(usize, zigwin.HEIGHT);
        backBuffer[x + y] = color;
    }

    if (failed(backup.IDirectDrawSurface7_Unlock(null))) win32Panic();

    // perform the flip
    while (failed(surface.IDirectDrawSurface7_Flip(null, draw.DDFLIP_WAIT))) {}

    std.time.sleep(500 * std.time.ns_per_ms);
}

fn gameShutdown() void {
    std.log.info("gameShutdown", .{});
    _ = backup.IUnknown_Release();
    _ = surface.IUnknown_Release();
    _ = draw7.IUnknown_Release();
}

fn win32Panic() noreturn {
    zigwin.win32Panic();
}
