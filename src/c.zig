const std = @import("std");

pub const stbImage = struct {
    const stb = @cImport(@cInclude("stb_image.h"));

    const Image = struct { data: []u8 = &[_]u8{}, width: u32, height: u32 };

    pub fn load(path: [:0]const u8) !Image {
        var width: c_int, var height: c_int = .{ 0, 0 };
        const result = stb.stbi_load(path, &width, &height, 0, 4);
        if (result == null) return error.LoadImageFailed;

        var image: Image = .{ .width = @intCast(width), .height = @intCast(height) };
        image.data = @as([*]u8, @ptrCast(result))[0 .. image.width * image.height * 4];
        return image;
    }

    pub fn unload(self: Image) void {
        stb.stbi_image_free(self.data.ptr);
    }
};

pub const stbVorbis = struct {
    const stb = @cImport({
        @cDefine("STB_VORBIS_NO_PUSHDATA_API", {});
        @cDefine("STB_VORBIS_HEADER_ONLY", {});
        @cInclude("stb_Vorbis.c");
    });

    // const Image = struct { data: []u8 = &[_]u8{}, width: u32, height: u32 };

    pub fn load(path: [:0]const u8) !void {
        // var width: c_int, var height: c_int = .{ 0, 0 };
        // const result = stb.stbi_load(path, &width, &height, 0, 4);
        // if (result == null) return error.LoadImageFailed;

        // var image: Image = .{ .width = @intCast(width), .height = @intCast(height) };
        // image.data = @as([*]u8, @ptrCast(result))[0 .. image.width * image.height * 4];
        // return image;
        var errorCode: c_int = 0;
        const file = stb.stb_vorbis_open_filename(path, &errorCode, null);

        const info = stb.stb_vorbis_get_info(file);
        std.log.info("stb info: {any}", .{info});
    }

    // pub fn unload(self: Image) void {
    //     stb.stbi_image_free(self.data.ptr);
    // }
};
