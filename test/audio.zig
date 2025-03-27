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

const div: f32 = 24103;
pub var state: AudioState = undefined;

fn callback(b: [*c]f32, f: i32, channels: i32) callconv(.C) void {
    _ = channels;

    // std.log.info("state frame: {d}", .{state.frame});

    const buffer = b[0..@as(usize, @intCast(f))];
    if (state.current + buffer.len < state.frame) {
        @memcpy(buffer, state.audio.samples()[state.current..][0..buffer.len]);
        state.current += buffer.len;
        return;
    }

    var len: usize = state.frame - state.current;
    @memcpy(buffer[0..len], state.audio.samples()[state.current..][0..len]);

    len = buffer.len - len;
    state.current = len;
    @memcpy(buffer[len..], state.audio.samples()[0..len]);

    // for (0..frames) |index| {
    //     const i = index * 2;
    //     state.current += 1;

    //     if (state.current >= state.frame - 1) state.current = 0;
    //     var value: f32 = @floatFromInt(state.audio.samples()[state.current]);
    //     buffer[i] = value / div;
    //     std.log.info("buffer: {d}", .{buffer[i]});
    //     // std.log.info("buffer: {d}", .{buffer[i]});
    //     value = @floatFromInt(state.audio.samples()[state.current + 1]);
    //     buffer[i + 1] = value / div;
    // }

    // std.log.info("state current: {d}", .{state.current});

    // const samples: usize = @intCast(frames * channels);

    // const dest = buffer[0..samples];
    // @memset(dest, 0);

    // const count = writeSamples(clip, p.frame, @as(usize, @intCast(num_frames)), dst, p.volume());
    // p.frame += count;

    // if (p.frame >= clip.frameCount()) {
    //     if (p.loop) {
    //         // TODO I don't think this is a perfect loop
    //         p.frame = 0;
    //     } else {
    //         p.clip = null;
    //         p.frame = 0;
    //     }
    // }
}

// fn writeSamples(clip: WavAudio, frame_offset: usize, frame_count: usize, output: []f32, volume: f32) usize {
//     const clip_samples = clip.samples();
//     const sample_offset = frame_offset * clip.format.nbrChannels;
//     const frames_left = @divExact(clip_samples.len, clip.format.nbrChannels) - frame_offset;
//     const frames_to_write = @min(sample_buf_length, @min(frame_count, frames_left));

//     const src = clip_samples[sample_offset .. sample_offset + frames_to_write * clip.format.nbrChannels];
//     const dst = output[0 .. frames_to_write * state.num_channels];

//     for (src, 0..) |s, i| {
//         const fs: f32 = @floatFromInt(s);
//         const div: usize = if (fs < 0) @abs(std.math.minInt(i16)) else std.math.maxInt(i16);
//         const result = (fs / @as(f32, @floatFromInt(div)));
//         std.debug.assert(-1 <= result and result <= 1);
//         if (clip.format.nbrChannels == 1) {
//             dst[i * state.num_channels + 0] += result * volume;
//             dst[i * state.num_channels + 1] += result * volume;
//         } else if (clip.format.nbrChannels == 2) {
//             dst[i] += result * volume;
//         } else unreachable;
//     }

//     return frames_to_write;
// }

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

    pub fn samples(self: WavAudio) []align(1) const f32 {
        return std.mem.bytesAsSlice(f32, self.data);
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
