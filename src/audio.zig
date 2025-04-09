const std = @import("std");
const sk = @import("sokol");
const cache = @import("cache.zig");
const c = @import("c.zig");

pub fn init(soundBuffer: []Sound) void {
    sk.audio.setup(.{
        .num_channels = 2,
        .stream_cb = callback,
        .logger = .{ .func = sk.log.func },
    });
    sounds = .initBuffer(soundBuffer);
}

pub fn deinit() void {
    stopMusic();
    sk.audio.shutdown();
}

var mutex: std.Thread.Mutex = .{};

pub const Music = struct {
    source: *c.stbAudio.Audio,
    paused: bool = false,
};

var music: ?Music = null;

pub fn playMusic(path: [:0]const u8) void {
    stopMusic();

    const audio = c.stbAudio.load(path) catch unreachable;
    const info = c.stbAudio.getInfo(audio);
    const args = .{ path, info.sample_rate, info.channels };
    std.log.info("music path: {s}, sampleRate: {}, channels: {d}", args);
    music = .{ .source = audio };
}

pub fn pauseMusic() void {
    if (music) |*value| value.paused = true;
}

pub fn resumeMusic() void {
    if (music) |*value| value.paused = false;
}

pub fn stopMusic() void {
    if (music) |*value| {
        c.stbAudio.unload(value.source);
        music = null;
    }
}

var sounds: std.ArrayListUnmanaged(Sound) = .empty;

pub const Sound = struct {
    source: []f32,
    valid: bool = true,
    loop: bool = true,
    index: u32 = 0,
    sampleRate: u16 = 0,
    channels: u8 = 0,
};

pub fn playSound(path: [:0]const u8) void {
    var sound = playSoundLoop(path);
    sound.loop = false;
}

pub fn playSoundLoop(path: [:0]const u8) *Sound {
    const sound = cache.Sound.load(path);

    const args = .{ path, sound.sampleRate, sound.channels };
    std.log.info("audio path: {s}, sampleRate: {}, channels: {d}", args);

    mutex.lock();
    defer mutex.unlock();
    sounds.appendAssumeCapacity(sound);
    return &sounds.items[sounds.items.len - 1];
}

fn callback(b: [*c]f32, frames: i32, channels: i32) callconv(.C) void {
    const buffer = b[0..@as(usize, @intCast(frames * channels))];
    @memset(buffer, 0);

    if (music) |m| blk: {
        if (m.paused) break :blk;
        const count = c.stbAudio.fillSamples(m.source, buffer, channels);
        if (count == 0) c.stbAudio.reset(m.source);
    }

    mutex.lock();
    defer mutex.unlock();

    for (sounds.items) |*value| {
        const sampleCount = c.stbAudio.fillSamples(value.source, buffer, channels);
        if (sampleCount != 0) continue;

        c.stbAudio.reset(value.source);
        if (!value.loop) value.valid = false;
    }
    {
        var i: usize = 0;
        while (i < sounds.items.len) : (i += 1) {
            if (sounds.items[i].valid) continue;
            _ = sounds.swapRemove(i);
        }
    }
}
