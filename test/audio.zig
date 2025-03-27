const std = @import("std");
const sk = @import("sokol");

pub fn init() void {
    sk.audio.setup(.{
        .num_channels = 2,
        .stream_cb = callback,
        .logger = .{ .func = sk.log.func },
    });

    const channel = sk.audio.channels();
    const sampleRate = sk.audio.sampleRate();
    const bufferFrames = sk.audio.bufferFrames();

    std.log.info("channels: {d}, sample rate: {d}", .{ channel, sampleRate });
    std.log.info("buffer frames: {d}", .{bufferFrames});
}

pub const AudioState = struct {
    audio: WavAudio,
    frame: usize,
    loop: bool = true,
    current: usize = 0,
};

const div = std.math.maxInt(i16);
pub var state: AudioState = undefined;

fn callback(b: [*c]f32, frames: i32, channels: i32) callconv(.C) void {
    const buffer = b[0..@as(usize, @intCast(frames * channels))];
    // @memset(buffer, 0);

    // if (sk.audio.sampleRate() != state.audio.header.sampleRate) {
    resampleAudio(buffer, @intCast(sk.audio.sampleRate()));
    // }

    // for (buffer) |*dst| {
    //     const value: f32 = @floatFromInt(state.audio.samples()[state.current]);
    //     dst.* = value / div;
    //     state.current += 1;
    //     if (state.current >= state.frame) state.current = 0;
    // }
}

fn resampleAudio(buffer: []f32, sampleRate: u16) void {
    const ratio = @divExact(sampleRate, state.audio.header.sampleRate);

    for (0..@divExact(buffer.len, ratio)) |i| {
        var next: f32 = 0;
        if (state.current + 1 >= state.frame) {
            next = @floatFromInt(state.audio.samples()[0]);
        } else {
            next = @floatFromInt(state.audio.samples()[state.current + 1]);
        }
        const current: f32 = @floatFromInt(state.audio.samples()[state.current]);
        const step = (next - current) / @as(f32, @floatFromInt(ratio));
        for (0..ratio) |j| {
            const value: f32 = (current + step * @as(f32, @floatFromInt(j))) / div;
            // std.log.info("value: {d}", .{value});
            if (value > 0.9) std.log.info("value: {d}", .{value});
            buffer[i * ratio + j] = value;
        }
        state.current += 1;
        if (state.current >= state.frame) {
            state.current = 0;
            std.log.info("loop...", .{});
        }
    }
}

pub fn deinit() void {
    sk.audio.shutdown();
}

pub const RiffChunk = struct {
    data: []const u8,
    const id = std.mem.bytesToValue(u32, "RIFF");

    pub fn parse(data: []const u8) ?RiffChunk {
        if (data.len < 8) return null;

        const actualId = std.mem.bytesToValue(u32, data[0..4]);
        if (actualId != id) return null;

        const size = std.mem.bytesToValue(u32, data[4..8]);
        if (data.len < 8 + size) return null;

        return RiffChunk{ .data = data[8..][0..size] };
    }
};

pub const WavAudio = struct {
    const dataId = std.mem.bytesToValue(u32, "data");
    header: WavFormatChunk,
    data: []const u8,

    pub fn parse(data: []const u8) ?WavAudio {
        const header = WavFormatChunk.parse(data) orelse return null;

        const withoutHeader = data[36..];
        const actualDataId = std.mem.bytesToValue(u32, withoutHeader[0..4]);
        if (actualDataId != dataId) return null;

        const size = std.mem.bytesToValue(u32, withoutHeader[4..8]);
        if (size + 8 != withoutHeader.len) return null;
        return .{ .header = header, .data = withoutHeader[8..] };
    }

    pub fn frameCount(self: WavAudio) usize {
        return @divExact(self.samples().len, self.header.channels);
    }

    pub fn samples(self: WavAudio) []align(1) const i16 {
        return std.mem.bytesAsSlice(i16, self.data);
    }
};

pub const WavFormatChunk = packed struct {
    const formType = std.mem.bytesToValue(u32, "WAVE");
    const id = std.mem.bytesToValue(u32, "fmt ");

    audioFormat: u16, // Audio format (1: PCM integer, 3: IEEE 754 float)
    channels: u16, // Number of channels
    sampleRate: u32, // Sample rate (in hertz)
    bytesPerSecond: u32, // Number of bytes to read per second
    bytesPerBlock: u16, // Number of bytes per block (NbrChannels * BitsPerSample / 8).
    bitsPerSample: u16, // Number of bits per sample

    pub fn parse(data: []const u8) ?WavFormatChunk {
        return parseFromRiff(RiffChunk.parse(data));
    }

    pub fn parseFromRiff(chunk: ?RiffChunk) ?WavFormatChunk {
        const riff = chunk orelse return null;

        const actualFormType = std.mem.bytesToValue(u32, riff.data[0..4]);
        if (actualFormType != formType) return null;

        const actualId = std.mem.bytesToValue(u32, riff.data[4..8]);
        if (actualId != id) return null;

        const size = std.mem.bytesToValue(u32, riff.data[8..12]);
        if (size != 16) @panic("unsupported wav format");

        const wavFormat = riff.data[12..@sizeOf(WavFormatChunk)];
        return std.mem.bytesAsValue(WavFormatChunk, wavFormat).*;
    }
};
