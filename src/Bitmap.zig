const std = @import("std");
const win32 = @import("win32");

fileHeader: win32.graphics.gdi.BITMAPFILEHEADER,
infoHeader: win32.graphics.gdi.BITMAPINFOHEADER,
colors: []u32,

const bitmapId: u16 = 0x4D42;

pub fn init(fileName: [:0]const u8) !@This() {
    var bitmap: @This() = undefined;

    const file = win32.storage.file_system;
    const windows = win32.system.windows_programming;

    // open the file if it exists
    var fileData: file.OFSTRUCT = undefined;
    const fileHandle = file.OpenFile(fileName, &fileData, file.OF_READ);
    if (fileHandle == -1) win32Panic();
    defer _ = windows._lclose(fileHandle);

    // now load the bitmap file header
    var len: u32 = @sizeOf(win32.graphics.gdi.BITMAPFILEHEADER);
    _ = windows._lread(fileHandle, &bitmap.fileHeader, len);

    // test if this is a bitmap file
    if (bitmap.fileHeader.bfType != bitmapId) @panic("not bitmap");

    // now we know this is a bitmap, so read in all the sections

    // first the bitmap infoheader

    // now load the bitmap file header
    len = @sizeOf(win32.graphics.gdi.BITMAPINFOHEADER);
    _ = windows._lread(fileHandle, &bitmap.infoHeader, len);

    // now load the color palette if there is one
    std.log.debug("bit count: {d}", .{bitmap.infoHeader.biBitCount});

    // // finally the image data itself
    const end = win32.media.multimedia.SEEK_END;
    const offset: i32 = @intCast(bitmap.infoHeader.biSizeImage);
    _ = windows._llseek(fileHandle, -offset, end);

    // allocate the memory for the image
    len = bitmap.infoHeader.biSizeImage;
    const buffer = try std.heap.page_allocator.alloc(u8, len);
    defer std.heap.page_allocator.free(buffer);

    _ = windows._lread(fileHandle, buffer.ptr, len);

    bitmap.colors = try std.heap.page_allocator.alloc(u32, len / 3);
    for (bitmap.colors, 0..) |*color, i| {
        color.* = @as(u24, @intCast(buffer[3 * i + 2])) << 16 //
        | @as(u24, @intCast(buffer[3 * i + 1])) << 8 | buffer[3 * i];
    }

    // flip the bitmap
    flipBitmap(bitmap.colors, @intCast(bitmap.infoHeader.biHeight));
    return bitmap;
}

fn flipBitmap(image: []u32, height: usize) void {
    // this function is used to flip bottom-up .BMP images

    // allocate the temporary buffer
    const buffer = std.heap.page_allocator.dupe(u32, image) catch unreachable;
    defer std.heap.page_allocator.free(buffer);

    // flip vertically
    const width = image.len / height;
    for (0..height) |index| {
        const source = buffer[index * width ..][0..width];
        const dest = image[(height - index - 1) * width ..][0..width];
        @memcpy(dest, source);
    }
}

pub fn deinit(self: *@This()) void {
    std.heap.page_allocator.free(self.colors);
}

fn win32Panic() void {
    @panic(@tagName(win32.foundation.GetLastError()));
}
