const std = @import("std");
const sk = @import("sokol");
const assets = @import("assets.zig");
const c = @import("c.zig");

pub fn init(sampleRate: u32, soundBuffer: []Sound) void {
    sk.audio.setup(.{
        .num_channels = 2,
        .sample_rate = @intCast(sampleRate),
        .stream_cb = callback,
        .logger = .{ .func = sk.log.func },
    });
    sounds = soundBuffer;
}

pub fn deinit() void {
    stopMusic();
    for (sounds) |*sound| sound.valid = false;
    sk.audio.shutdown();
}

const Music = struct {
    source: *c.stbAudio.Audio = undefined,
    paused: bool = false,
    loop: bool = true,
    active: bool = false,

    fn init(data: []const u8, loop: bool) Music {
        const source = c.stbAudio.loadFromMemory(data) catch unreachable;
        return .{ .source = source, .loop = loop, .active = true };
    }

    fn loader(allocator: std.mem.Allocator, buffer: *[]const u8) void {
        const data = allocator.dupe(u8, buffer.*);
        buffer.* = data catch unreachable;
        if (music) |*m| music = Music.init(buffer.*, m.loop);
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
    stopMusic();

    const file = assets.File.load(path, Music.loader);
    if (file.data.len != 0) {
        music = Music.init(file.data, loop);
    } else {
        music = .{ .loop = loop };
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
    source: []f32,
    valid: bool = false,
    loop: bool = true,
    index: usize = 0,
    sampleRate: u16 = 0,
    channels: u8 = 0,
};
pub const SoundIndex = usize;

pub fn playSound(path: [:0]const u8) void {
    _ = doPlaySound(path, false);
}

pub fn playSoundLoop(path: [:0]const u8) SoundIndex {
    return doPlaySound(path, true);
}

pub fn stopSound(sound: SoundIndex) void {
    sounds[sound].valid = false;
}

fn doPlaySound(path: [:0]const u8, loop: bool) SoundIndex {
    var sound = assets.Sound.load(path);
    sound.loop = loop;

    return addItem(sounds, sound);
}

fn addItem(slice: anytype, item: anytype) usize {
    for (slice, 0..) |*value, index| {
        if (!value.valid) {
            value.* = item;
            return index;
        }
    }
    @panic("too many audio sound");
}

export fn callback(b: [*c]f32, frames: i32, channels: i32) void {
    const buffer = b[0..@as(usize, @intCast(frames * channels))];
    @memset(buffer, 0);
    {
        if (music) |m| blk: {
            if (m.paused or !m.active) break :blk;
            const count = c.stbAudio.fillSamples(m.source, buffer, channels);
            if (count == 0) {
                if (m.loop) c.stbAudio.reset(m.source) else music = null;
            }
        }
    }

    for (sounds) |*sound| {
        if (!sound.valid) continue;
        var len = mixSamples(buffer, sound);
        while (len < buffer.len and sound.valid) {
            len += mixSamples(buffer[len..], sound);
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
        if (sound.loop) sound.index = 0 else sound.valid = false;
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
