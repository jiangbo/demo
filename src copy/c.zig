const std = @import("std");

pub const stbImage = struct {
    const stb = @cImport(@cInclude("stb_image.h"));

    const Image = struct { data: []u8 = &[_]u8{}, width: u32, height: u32 };

    pub fn load(path: [:0]const u8) ?Image {
        var width: c_int, var height: c_int = .{ 0, 0 };
        const result = stb.stbi_load(path, &width, &height, 0, 4) orelse return null;
        var image: Image = .{ .width = @intCast(width), .height = @intCast(height) };
        image.data = @as([*]u8, @ptrCast(result))[0 .. image.width * image.height * 4];
        return image;
    }

    pub fn unload(self: Image) void {
        stb.stbi_image_free(self.data.ptr);
    }
};
