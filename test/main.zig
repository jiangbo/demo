const std = @import("std");

const audio = @import("audio.zig");

pub fn main() !void {
    const wavData: []const u8 = @embedFile("ui_win.wav");

    const wav = audio.WavAudio.parse(wavData);
    audio.state = .{ .audio = wav.?, .frame = wav.?.samples().len };

    std.log.info("sample rate: {d}", .{wav.?.header.sampleRate});

    audio.init();
    defer audio.deinit();

    // const a: i16 = 0x7fffffff;
    // const b: i16 = std.math.maxInt(i16);
    // std.log.info("number a: {d}, b: {b}", .{ a, b });

    std.Thread.sleep(10 * std.time.ns_per_s);
}
