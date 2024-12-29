const std = @import("std");
const win32 = @import("win32");

pub const Wave = struct {
    allocator: std.mem.Allocator,
    format: win32.media.audio.WAVEFORMATEX,
    size: u32,
    data: []i8,

    pub fn init(allocator: std.mem.Allocator, name: [*:0]const u16) Wave {
        const media = win32.media.multimedia;
        const flags = media.MMIO_ALLOCBUF | media.MMIO_READ;
        const mmio = media.mmioOpenW(@constCast(@ptrCast(name)), null, flags);
        if (mmio == null) @panic("failed to open wave file");
        defer _ = media.mmioClose(mmio, 0);

        var riff: media.MMCKINFO = undefined;
        riff.fccType = media.mmioStringToFOURCCW(win32.zig.L("WAVE"), 0);
        var result = media.mmioDescend(mmio, &riff, null, media.MMIO_FINDRIFF);
        if (result != win32.media.MMSYSERR_NOERROR) @panic("failed to descend riff");

        var chunk: media.MMCKINFO = undefined;
        chunk.ckid = media.mmioStringToFOURCCW(win32.zig.L("fmt "), 0);
        result = media.mmioDescend(mmio, &chunk, &riff, media.MMIO_FINDCHUNK);
        if (result != win32.media.MMSYSERR_NOERROR) @panic("failed to descend chunk");

        var wave: Wave = std.mem.zeroInit(Wave, .{ .allocator = allocator });
        const size = @sizeOf(@TypeOf(wave.format));
        var read = media.mmioRead(mmio, @ptrCast(&wave.format), size);
        if (read == -1) @panic("failed to read format");

        result = media.mmioAscend(mmio, &chunk, 0);
        if (result != win32.media.MMSYSERR_NOERROR) @panic("failed to ascend chunk");

        chunk.ckid = media.mmioStringToFOURCCW(win32.zig.L("data"), 0);
        result = media.mmioDescend(mmio, &chunk, &riff, media.MMIO_FINDCHUNK);
        if (result != win32.media.MMSYSERR_NOERROR) @panic("failed to descend chunk");

        wave.data = allocator.alloc(i8, chunk.cksize) catch unreachable;
        read = media.mmioRead(mmio, @ptrCast(wave.data.ptr), @intCast(wave.data.len));
        if (result == -1) @panic("failed to read data");

        return wave;
    }

    pub fn deinit(self: Wave) void {
        self.allocator.free(self.data);
    }
};
