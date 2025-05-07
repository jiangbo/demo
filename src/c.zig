const std = @import("std");

pub const stbImage = struct {
    const stb = @cImport(@cInclude("stb_image.h"));

    pub const Image = struct { data: []u8 = &[_]u8{}, width: i32, height: i32 };

    pub fn load(path: [:0]const u8) !Image {
        var width: i32, var height: i32 = .{ 0, 0 };

        const result = stb.stbi_load(path, &width, &height, 0, 4);
        if (result == null) return error.LoadImageFailed;

        var image: Image = .{ .width = width, .height = height };
        image.data = @as([*]u8, @ptrCast(result))[0 .. image.width * image.height * 4];
        return image;
    }

    pub fn loadFromMemory(buffer: []const u8) !Image {
        var width: i32, var height: i32 = .{ 0, 0 };
        const result = stb.stbi_load_from_memory(buffer.ptr, @intCast(buffer.len), &width, &height, 0, 4);
        if (result == null) return error.LoadImageFailed;
        var image: Image = .{ .width = width, .height = height };
        const size: usize = @intCast(image.width * image.height * 4);
        image.data = @as([*]u8, @ptrCast(result))[0..size];
        return image;
    }

    pub fn unload(self: Image) void {
        stb.stbi_image_free(self.data.ptr);
    }
};

pub const stbAudio = stbVorbis;
pub const stbVorbis = struct {
    const stb = @cImport({
        @cDefine("STB_VORBIS_NO_PUSHDATA_API", {});
        @cDefine("STB_VORBIS_HEADER_ONLY", {});
        @cDefine("STB_VORBIS_NO_INTEGER_CONVERSION", {});
        @cDefine("STB_VORBIS_NO_STDIO", {});
        @cInclude("stb_Vorbis.c");
    });

    pub const AudioInfo = stb.stb_vorbis_info;
    pub const Audio = struct {
        audio: *stb.stb_vorbis,

        pub fn init(data: []const u8) !Audio {
            var errorCode: c_int = 0;

            const vorbis = stb.stb_vorbis_open_memory(data.ptr, @intCast(data.len), &errorCode, null);
            if (errorCode != 0 or vorbis == null) return error.loadAudioFailed;
            return vorbis.?;
        }

        pub fn getInfo(self: *Audio) AudioInfo {
            return stb.stb_vorbis_get_info(self.audio);
        }

        pub fn getSampleCount(self: *Audio) usize {
            return stb.stb_vorbis_stream_length_in_samples(self.audio);
        }

        pub fn unload(self: *Audio) void {
            stb.stb_vorbis_close(self.audio);
        }
    };

    pub fn fillSamples(self: *Audio, buffer: []f32, channels: i32) c_int {
        return stb.stb_vorbis_get_samples_float_interleaved(
            self.audio,
            channels,
            @ptrCast(buffer),
            @intCast(buffer.len),
        );
    }

    pub fn reset(self: *Audio) void {
        _ = stb.stb_vorbis_seek_start(self.audio);
    }
};
