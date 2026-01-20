const std = @import("std");

const raw = @embedFile("atlas1.png");
const signature = [8]u8{ 137, 80, 78, 71, 13, 10, 26, 10 };

const ChunkEnum = enum(u32) {
    IHDR = std.mem.readInt(u32, "IHDR", .big),
    PLTE = std.mem.readInt(u32, "PLTE", .big),
    tRNS = std.mem.readInt(u32, "tRNS", .big),
    IDAT = std.mem.readInt(u32, "IDAT", .big),
    IEND = std.mem.readInt(u32, "IEND", .big),
    _,
};

const ColorEnum = enum(u8) {
    grayScale = 0,
    trueColor = 2,
    indexed = 3,
    grayScaleAlpha = 4,
    trueColorAlpha = 6,
};

const FilterEnum = enum(u8) {
    none = 0,
    sub = 1,
    up = 2,
    average = 3,
    paeth = 4,
};

const Header = extern struct {
    width: u32,
    height: u32,
    bitDepth: u8,
    colorEnum: ColorEnum,
    compression: u8,
    filter: u8,
    interlace: u8,
};

const Chunk = struct { chunkEnum: ChunkEnum, data: []u8 };

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var reader = std.Io.Reader.fixed(raw);
    if (!std.mem.eql(u8, try reader.take(8), &signature)) {
        return error.InvalidSignature;
    }

    var chunk = try readChunk(&reader);
    var header = std.mem.bytesToValue(Header, chunk.data);
    std.mem.byteSwapAllFields(Header, &header);
    std.log.info("header: {any}", .{header});

    var compressData: std.ArrayList(u8) = .empty;
    defer compressData.deinit(allocator);

    var rgbPalette: []u8 = &.{};
    var trans: []u8 = &.{};
    var palette: []u8 = &.{};
    defer allocator.free(palette);

    while (chunk.chunkEnum != .IEND) {
        chunk = try readChunk(&reader);
        switch (chunk.chunkEnum) {
            .IDAT => try compressData.appendSlice(allocator, chunk.data),
            .PLTE => rgbPalette = chunk.data,
            .tRNS => trans = chunk.data,
            else => {},
        }
    }
    if (header.colorEnum == .indexed) {
        palette = try allocator.alloc(u8, rgbPalette.len / 3 * 4);
        for (0..palette.len / 4) |i| {
            palette[i * 4 + 0] = rgbPalette[i * 3 + 0];
            palette[i * 4 + 1] = rgbPalette[i * 3 + 1];
            palette[i * 4 + 2] = rgbPalette[i * 3 + 2];
            const alpha = if (i < trans.len) trans[i] else 255;
            palette[i * 4 + 3] = alpha;
        }
    }

    const capacity = header.width * header.height * 4;
    const pixelData = try allocator.alloc(u8, capacity);
    defer allocator.free(pixelData);
    switch (header.colorEnum) {
        .trueColorAlpha => try parseRgba(pixelData, header, compressData.items),
        .indexed => try parseIndexed(pixelData, header, compressData.items, palette),
        else => return error.UnsupportedColorType,
    }

    const image = Image.init(header.width, header.height, pixelData);
    try image.write("my.ppm");
}

fn readChunk(reader: *std.io.Reader) !Chunk {
    const length: u32 = try reader.takeInt(u32, .big);
    const crcBytes = try reader.peek(length + @sizeOf(ChunkEnum));

    const chunkType = try reader.peek(4);
    std.log.info("chunk: {s}", .{chunkType});
    const chunkEnum = try reader.takeEnum(ChunkEnum, .big);
    const data = try reader.take(length);

    const crc = try reader.takeInt(u32, .big);
    if (crc != std.hash.Crc32.hash(crcBytes)) return error.InvalidCrc;

    return .{ .chunkEnum = chunkEnum, .data = data };
}

fn parseIndexed(data: []u8, header: Header, compress: []u8, palette: []u8) !void {
    std.log.info("compress data len: {}", .{compress.len});

    var reader = std.Io.Reader.fixed(compress);
    var decompressBuffer: [std.compress.flate.max_window_len]u8 = undefined;
    const Decompress = std.compress.flate.Decompress;
    var decompress = Decompress.init(&reader, .zlib, &decompressBuffer);

    const start: usize = header.width * header.height * 3;

    for (0..header.height) |y| {
        const filterEnum = try decompress.reader.takeEnum(FilterEnum, .big);
        // std.log.info("filter: {}", .{filterEnum});
        const current = try decompress.reader.take(header.width);
        const offset = start + y * header.width;

        switch (filterEnum) {
            .none => @memcpy(data[offset..][0..header.width], current),
            else => return error.OnlyNoneIndexedSupported,
        }
    }
    std.log.info("decompress data len: {}", .{header.width * header.height});

    // 将索引转换为RGBA
    for (data[start..], 0..) |pixel, index| {
        const pixelIndex = @as(usize, pixel) * 4;
        data[index * 4 + 0] = palette[pixelIndex + 0];
        data[index * 4 + 1] = palette[pixelIndex + 1];
        data[index * 4 + 2] = palette[pixelIndex + 2];
        data[index * 4 + 3] = palette[pixelIndex + 3];
    }
}

fn parseRgba(pixelData: []u8, header: Header, compressData: []u8) !void {
    std.log.info("compress data len: {}", .{compressData.len});

    var reader = std.Io.Reader.fixed(compressData);
    var decompressBuffer: [std.compress.flate.max_window_len]u8 = undefined;
    const Decompress = std.compress.flate.Decompress;
    var decompress = Decompress.init(&reader, .zlib, &decompressBuffer);
    const lineLen = header.width * 4;

    var prior: []u8 = &.{};
    for (0..header.height) |index| {
        const filterEnum = try decompress.reader.takeEnum(FilterEnum, .big);
        // std.log.info("filter: {}", .{filterEnum});
        const current = try decompress.reader.take(lineLen);
        const dest = pixelData[index * lineLen ..][0..lineLen];
        switch (filterEnum) {
            .none => @memcpy(dest, current),
            .sub => {
                for (0..4) |i| dest[i] = current[i];
                const left = dest[0 .. dest.len - 4];
                for (current[4..], left, dest[4..]) |c, l, *d| {
                    d.* = c +% l;
                }
            },
            .up => {
                for (current, prior, dest) |c, p, *d| d.* = c +% p;
            },
            .average => {
                // 手动算第一个像素
                for (0..4) |i| dest[i] = current[i] + (prior[i] / 2);

                const left = dest[0 .. dest.len - 4];
                for (current[4..], left, prior[4..], dest[4..]) |c, l, p, *d|
                    d.* = c +% ((l + p) / 2);
            },
            .paeth => {
                // 手动算第一个像素
                for (0..4) |i| dest[i] = current[i] +% paeth(0, prior[i], 0);

                const left = dest[0 .. dest.len - 4];
                const priorLeft = prior[0 .. prior.len - 4];

                for (current[4..], left, prior[4..], priorLeft, dest[4..]) |c, l, p, pl, *d|
                    d.* = c +% paeth(l, p, pl);
            },
        }
        prior = dest;
    }
    std.log.info("decompress data len: {}", .{pixelData.len});
}

fn paeth(a: u8, b: u8, c: u8) u8 {
    const p = @as(i16, a) + b - c;
    const pa = @abs(p - a);
    const pb = @abs(p - b);
    const pc = @abs(p - c);
    if (pa <= pb and pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
}

pub const Image = struct {
    width: usize,
    height: usize,
    data: []u8,
    pub fn init(width: usize, height: usize, data: []u8) Image {
        std.debug.assert(data.len == width * height * 4);
        return Image{ .width = width, .height = height, .data = data };
    }

    pub fn write(self: Image, path: []const u8) !void {
        var file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        var buffer: [1024]u8 = undefined;
        var writer = file.writer(&buffer);

        try writer.interface.print(
            \\P7
            \\WIDTH {}
            \\HEIGHT {}
            \\DEPTH 4
            \\MAXVAL 255
            \\TUPLTYPE RGB_ALPHA
            \\ENDHDR
            \\
        , .{
            self.width,
            self.height,
        });
        try writer.interface.writeAll(self.data);
        try writer.interface.flush();
    }
};
