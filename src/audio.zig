const std = @import("std");
const sk = @import("sokol");
const assets = @import("assets.zig");
const stbAudio = @import("c.zig").stbAudio;

pub fn init(sampleRate: u32, soundBuffer: []Sound) void {
    sk.audio.setup(.{
        .num_channels = 2,
        .sample_rate = @intCast(sampleRate),
        .stream_cb = audioCallback,
        .logger = .{ .func = sk.log.func },
    });
    sounds = soundBuffer;
    for (sounds) |*sound| sound.state = .stopped;
}

pub fn deinit() void {
    stopMusic();
    for (sounds) |*sound| sound.state = .stopped;
    sk.audio.shutdown();
}

const Music = struct {
    source: *stbAudio.Audio = undefined,
    paused: bool = false,
    loop: bool = true,

    fn init(data: []const u8, loop: bool) Music {
        const source = stbAudio.Audio.init(data) catch unreachable;
        return .{ .source = source, .loop = loop };
    }

    fn loader(res: assets.Response) []const u8 {
        const content, const allocator = .{ res.data, res.allocator };
        const data = allocator.dupe(u8, content) catch unreachable;
        if (music) |*m| music = Music.init(data, m.loop);
        return data;
    }
};

pub var music: ?Music = null;

pub fn playMusic(path: [:0]const u8) void {
    doPlayMusic(path, true);
}

pub fn playMusicOnce(path: [:0]const u8) void {
    doPlayMusic(path, false);
}

fn doPlayMusic(path: [:0]const u8, loop: bool) void {
    const file = assets.File.load(path, 0, Music.loader);
    if (file.index.state == .handled) {
        music = Music.init(file.data, loop);
    } else {
        music = .{ .loop = loop, .paused = true };
    }
}

pub fn pauseMusic() void {
    if (music) |*value| value.paused = true;
}

pub fn resumeMusic() void {
    if (music) |*value| value.paused = false;
}

pub fn stopMusic() void {
    music = null;
}

pub var sounds: []Sound = &.{};

pub const Sound = struct {
    handle: SoundHandle,
    source: []f32 = &.{},
    loop: bool = true,
    index: usize = 0,
    sampleRate: u16 = 0,
    channels: u8 = 0,
    state: enum { init, playing, paused, stopped } = .init,
};
pub const SoundHandle = usize;

pub fn playSound(path: [:0]const u8) void {
    _ = assets.Sound.load(path, false);
}

pub fn playSoundLoop(path: [:0]const u8) SoundHandle {
    const sound = assets.loadSound(path, false);
    return sound.handle;
}

pub fn stopSound(sound: SoundHandle) void {
    sounds[sound].state = .stopped;
}

export fn audioCallback(b: [*c]f32, frames: i32, channels: i32) void {
    const buffer = b[0..@as(usize, @intCast(frames * channels))];
    @memset(buffer, 0);

    if (music != null and !music.?.paused) {
        const source = music.?.source;
        const count = stbAudio.fillSamples(source, buffer, channels);
        if (count == 0) {
            if (music.?.loop) stbAudio.reset(source) else music = null;
        }
    }

    for (sounds) |*sound| {
        if (sound.state == .playing) {
            var len = mixSamples(buffer, sound);
            while (len < buffer.len and sound.state == .playing) {
                len += mixSamples(buffer[len..], sound);
            }
        }
    }
}

fn mixSamples(buffer: []f32, sound: *Sound) usize {
    const len = if (sound.channels == 1)
        mixMonoSamples(buffer, sound)
    else if (sound.channels == 2)
        mixStereoSamples(buffer, sound)
    else
        std.debug.panic("unsupported channels: {d}", .{sound.channels});

    if (sound.index == sound.source.len) {
        if (sound.loop) sound.index = 0 else sound.state = .stopped;
    }

    return len;
}

fn mixStereoSamples(dstBuffer: []f32, sound: *Sound) usize {
    const srcBuffer = sound.source[sound.index..];
    const len = @min(dstBuffer.len, srcBuffer.len);

    for (0..len) |index| dstBuffer[index] += srcBuffer[index];
    sound.index += len;
    return len;
}

fn mixMonoSamples(dstBuffer: []f32, sound: *Sound) usize {
    const srcBuffer = sound.source[sound.index..];
    const len = @min(dstBuffer.len / 2, srcBuffer.len);

    for (0..len) |index| {
        dstBuffer[index * 2] += srcBuffer[index];
        dstBuffer[index * 2 + 1] += srcBuffer[index];
    }
    sound.index += len;
    return len * 2;
}
