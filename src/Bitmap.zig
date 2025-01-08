const std = @import("std");
const win32 = @import("win32");

fileHeader: win32.graphics.gdi.BITMAPFILEHEADER,
infoHeader: win32.graphics.gdi.BITMAPINFOHEADER,
buffer: []u8,

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
    bitmap.buffer = try std.heap.page_allocator.alloc(u8, len);
    _ = windows._lread(fileHandle, bitmap.buffer.ptr, len);

    return bitmap;
}

pub fn deinit(self: *@This()) void {
    std.heap.page_allocator.free(self.buffer);
}

fn win32Panic() void {
    @panic(@tagName(win32.foundation.GetLastError()));
}
