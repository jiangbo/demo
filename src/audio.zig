const std = @import("std");
const sk = @import("sokol");
const assets = @import("assets.zig");
const c = @import("c.zig");

pub fn init(sampleRate: u32, soundBuffer: []Sound) void {
    sk.audio.setup(.{
        .num_channels = 2,
        .sample_rate = @intCast(sampleRate),
        .stream_cb = audioCallback,
        .logger = .{ .func = sk.log.func },
    });
    sounds = soundBuffer;
    for (sounds) |*sound| sound.handle.state = .remove;
}

pub fn deinit() void {
    stopMusic();
    for (sounds) |*sound| sound.handle.state = .remove;
    sk.audio.shutdown();
}

const Music = struct {
    source: *c.stbAudio.Audio = undefined,
    paused: bool = false,
    loop: bool = true,

    fn init(data: []const u8, loop: bool) Music {
        const source = c.stbAudio.loadFromMemory(data) catch unreachable;
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
    if (file.index.state == .loaded) {
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

var sounds: []Sound = &.{};

pub const Sound = struct {
    handle: SoundHandle,
    source: []f32,
    loop: bool = true,
    index: usize = 0,
    sampleRate: u16 = 0,
    channels: u8 = 0,

    fn init(stbAudio: c.stbAudio.Audio) Sound {
        var sound: Sound = undefined;

        const info = c.stbAudio.getInfo(stbAudio);
        sound.channels = @intCast(info.channels);
        sound.sampleRate = @intCast(info.sample_rate);

        const size = c.stbAudio.getSampleCount(stbAudio) * sound.channels;
        sound.source = allocator.alloc(f32, size) catch unreachable;

        _ = c.stbAudio.fillSamples(stbAudio, sound.source, sound.channels);
        sound.valid = true;
    }

    fn loader(res: assets.Response) []const u8 {
        const content, const allocator = .{ res.data, res.allocator };

        const stbAudio = c.stbAudio.loadFromMemory(content) catch unreachable;
        const info = c.stbAudio.getInfo(stbAudio);

        var sound = cache.getPtr(response.path).?;

        sound.channels = @intCast(info.channels);
        sound.sampleRate = @intCast(info.sample_rate);

        const size = c.stbAudio.getSampleCount(stbAudio) * sound.channels;
        sound.source = allocator.alloc(f32, size) catch unreachable;

        _ = c.stbAudio.fillSamples(stbAudio, sound.source, sound.channels);
        sound.valid = true;
    }
};
pub const SoundHandle = assets.AssetHandle;

pub fn playSound(path: [:0]const u8) void {
    _ = doPlaySound(path, false);
}

pub fn playSoundLoop(path: [:0]const u8) SoundHandle {
    return doPlaySound(path, true);
}

pub fn stopSound(sound: SoundHandle) void {
    sounds[sound].valid = false;
}

fn doPlaySound(path: [:0]const u8, loop: bool) SoundHandle {
    for (sounds, 0..) |*sound, index| {
        if (sound.handle.state != .remove) continue;

        const file = assets.File.load(path, @intCast(index), undefined);
        sound.loop = loop;
        sound.handle = file.handle.nextVersion();
        if (file.handle.state == .loaded) sound.handle.state = .active;

        return sound.handle;
    }

    @panic("too many audio sound");
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
        if (sound.handle.state == .active) {
            var len = mixSamples(buffer, sound);
            while (len < buffer.len and sound.handle.isActive()) {
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
        if (sound.loop) sound.index = 0 else sound.handle.state = .remove;
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
